from pathlib import Path

cubit_path = Path(r"lib\features\staff\presentation\cubit\chat\chat_cubit.dart")
state_path = Path(r"lib\features\staff\presentation\cubit\chat\chat_state.dart")

cubit = cubit_path.read_text(encoding="utf-8")
state = state_path.read_text(encoding="utf-8")

needed_imports = [
    "import 'package:equatable/equatable.dart';",
    "import '../../../data/models/chat_message.dart';",
]

# 1. Добавляем нужные imports в chat_cubit.dart, если их там нет.
for imp in needed_imports:
    if imp not in cubit:
        # вставляем после последнего import
        lines = cubit.splitlines()
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.strip().startswith("import "):
                last_import_idx = i

        if last_import_idx >= 0:
            lines.insert(last_import_idx + 1, imp)
        else:
            lines.insert(0, imp)

        cubit = "\n".join(lines) + "\n"
        print("ADDED TO CUBIT:", imp)

# 2. Удаляем import/library из chat_state.dart.
new_lines = []
for line in state.splitlines():
    stripped = line.strip()
    if stripped.startswith("import "):
        print("REMOVED FROM STATE:", stripped)
        continue
    if stripped.startswith("library "):
        print("REMOVED FROM STATE:", stripped)
        continue
    new_lines.append(line)

state = "\n".join(new_lines).strip() + "\n"

# 3. part of должен быть первой директивой.
if not state.startswith("part of 'chat_cubit.dart';"):
    state = state.replace("part of 'chat_cubit.dart';", "").strip()
    state = "part of 'chat_cubit.dart';\n\n" + state + "\n"

cubit_path.write_text(cubit, encoding="utf-8")
state_path.write_text(state, encoding="utf-8")

print("OK: chat_cubit/chat_state part-of imports fixed")
