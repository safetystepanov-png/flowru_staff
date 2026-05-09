from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_client_search_screen.dart")
s = path.read_text(encoding="utf-8")

s = s.replace(
"""          builder: (_) => StaffClientDetailScreen(
            establishmentId: widget.establishmentId,
            clientId: resolved.clientId,
          ),
""",
"""          builder: (_) => StaffClientDetailScreen(
            establishmentId: widget.establishmentId,
            establishmentName: resolved.establishmentName,
            clientId: resolved.clientId,
          ),
"""
)

path.write_text(s, encoding="utf-8")
print("establishmentName added to QR client detail open")
