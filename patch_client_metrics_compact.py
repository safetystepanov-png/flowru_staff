from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_client_detail_screen.dart")
text = path.read_text(encoding="utf-8")

replacements = {
    "      height: 150,": "      height: 126,",
    "      padding: const EdgeInsets.all(14),": "      padding: const EdgeInsets.all(13),",
    "              fontSize: 12,": "              fontSize: 11.5,",
    "              fontSize: 19,": "              fontSize: 18,",
    "              fontSize: 11.5,": "              fontSize: 11,",
}

for old, new in replacements.items():
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
print("OK: metric cards compacted")
