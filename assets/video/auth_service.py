from datetime import timedelta

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.security import (
    create_access_token,
    create_refresh_token,
    generate_otp_code,
    utcnow,
)


def normalize_phone(phone: str) -> str:
    phone = phone.strip()
    allowed = set("+0123456789")
    cleaned = "".join(ch for ch in phone if ch in allowed)
    return cleaned


def _phone_has_staff_access(db: Session, phone: str) -> bool:
    row = db.execute(
        text(
            """
            SELECT 1
            FROM users u
            JOIN staff_memberships sm ON sm.user_id = u.id
            JOIN establishments e ON e.id = sm.establishment_id
            WHERE u.phone = :phone
              AND sm.is_active = true
              AND e.is_active = true
            LIMIT 1
            """
        ),
        {"phone": phone},
    ).first()
    return bool(row)


def _ensure_user_has_staff_access(db: Session, user_id: str) -> None:
    row = db.execute(
        text(
            """
            SELECT 1
            FROM staff_memberships sm
            JOIN establishments e ON e.id = sm.establishment_id
            WHERE sm.user_id = CAST(:user_id AS uuid)
              AND sm.is_active = true
              AND e.is_active = true
            LIMIT 1
            """
        ),
        {"user_id": user_id},
    ).first()

    if not row:
        raise ValueError("Вы не являетесь сотрудником ни одного из заведений")


def request_code(db: Session, phone: str) -> dict:
    phone = normalize_phone(phone)

    if not _phone_has_staff_access(db, phone):
        raise ValueError("Вы не являетесь сотрудником ни одного из заведений")

    code = generate_otp_code()
    expires_at = utcnow() + timedelta(minutes=5)

    db.execute(
        text(
            """
            INSERT INTO otp_codes (phone, code, purpose, expires_at, is_used)
            VALUES (:phone, :code, 'login', :expires_at, false)
            """
        ),
        {
            "phone": phone,
            "code": code,
            "expires_at": expires_at,
        },
    )
    db.commit()

    return {
        "status": "ok",
        "phone": phone,
        "code": code,
        "expires_in_seconds": 300,
    }


def verify_code(
    db: Session,
    phone: str,
    code: str,
    device_id: str,
    platform: str,
    full_name: str | None = None,
) -> dict:
    phone = normalize_phone(phone)

    otp_row = db.execute(
        text(
            """
            SELECT id, phone, code, expires_at, is_used
            FROM otp_codes
            WHERE phone = :phone
              AND code = :code
              AND purpose = 'login'
              AND is_used = false
            ORDER BY created_at DESC
            LIMIT 1
            """
        ),
        {
            "phone": phone,
            "code": code,
        },
    ).mappings().first()

    if not otp_row:
        raise ValueError("Неверный код или телефон")

    if otp_row["expires_at"] < utcnow():
        raise ValueError("Код истёк")

    db.execute(
        text(
            """
            UPDATE otp_codes
            SET is_used = true
            WHERE id = :otp_id
            """
        ),
        {"otp_id": otp_row["id"]},
    )

    user_row = db.execute(
        text(
            """
            SELECT id, phone, full_name
            FROM users
            WHERE phone = :phone
            LIMIT 1
            """
        ),
        {"phone": phone},
    ).mappings().first()

    if user_row:
        user_id = str(user_row["id"])
        user_full_name = user_row["full_name"]

        if full_name and not user_full_name:
            db.execute(
                text(
                    """
                    UPDATE users
                    SET full_name = :full_name,
                        phone_verified = true,
                        updated_at = NOW()
                    WHERE id = CAST(:user_id AS uuid)
                    """
                ),
                {
                    "user_id": user_id,
                    "full_name": full_name,
                },
            )
            user_full_name = full_name
    else:
        inserted = db.execute(
            text(
                """
                INSERT INTO users (phone, phone_verified, full_name, is_active)
                VALUES (:phone, true, :full_name, true)
                RETURNING id, phone, full_name
                """
            ),
            {
                "phone": phone,
                "full_name": full_name,
            },
        ).mappings().first()

        user_id = str(inserted["id"])
        user_full_name = inserted["full_name"]

    _ensure_user_has_staff_access(db=db, user_id=user_id)

    db.execute(
        text(
            """
            INSERT INTO user_devices (user_id, device_id, platform, last_seen_at)
            VALUES (CAST(:user_id AS uuid), :device_id, :platform, NOW())
            ON CONFLICT (user_id, device_id)
            DO UPDATE SET
                platform = EXCLUDED.platform,
                last_seen_at = NOW()
            """
        ),
        {
            "user_id": user_id,
            "device_id": device_id,
            "platform": platform,
        },
    )

    access_token = create_access_token(user_id=user_id, phone=phone)
    refresh_token, refresh_expires_at = create_refresh_token(
        user_id=user_id,
        phone=phone,
    )

    db.execute(
        text(
            """
            INSERT INTO refresh_tokens (user_id, token, expires_at, is_revoked)
            VALUES (CAST(:user_id AS uuid), :token, :expires_at, false)
            """
        ),
        {
            "user_id": user_id,
            "token": refresh_token,
            "expires_at": refresh_expires_at,
        },
    )

    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": user_id,
        "phone": phone,
        "full_name": user_full_name,
    }


def refresh_access_token(db: Session, refresh_token: str) -> dict:
    row = db.execute(
        text(
            """
            SELECT rt.user_id, rt.token, rt.expires_at, rt.is_revoked, u.phone
            FROM refresh_tokens rt
            JOIN users u ON u.id = rt.user_id
            WHERE rt.token = :refresh_token
            LIMIT 1
            """
        ),
        {"refresh_token": refresh_token},
    ).mappings().first()

    if not row:
        raise ValueError("Refresh token not found")

    if row["is_revoked"]:
        raise ValueError("Refresh token revoked")

    if row["expires_at"] < utcnow():
        raise ValueError("Refresh token expired")

    access_token = create_access_token(
        user_id=str(row["user_id"]),
        phone=row["phone"],
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
    }


def revoke_refresh_token(db: Session, refresh_token: str) -> dict:
    row = db.execute(
        text(
            """
            SELECT id
            FROM refresh_tokens
            WHERE token = :refresh_token
            LIMIT 1
            """
        ),
        {"refresh_token": refresh_token},
    ).mappings().first()

    if not row:
        raise ValueError("Refresh token not found")

    db.execute(
        text(
            """
            UPDATE refresh_tokens
            SET is_revoked = true
            WHERE id = :id
            """
        ),
        {"id": row["id"]},
    )
    db.commit()

    return {"status": "ok"}