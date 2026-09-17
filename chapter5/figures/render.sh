#!/bin/bash
# Render one QGIS job of the tessellations chapter and write a preview of it.
# Usage: render.sh <job.json> <preview.png>
set -e
cd "${OUT:-$PWD}"
out=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['output'])" "$1")
timeout 900 ${QGIS_PY:-cmd.exe /c "C:\\Program Files\\QGIS 3.40.15\\bin\\python-qgis-ltr.bat"} render_map.py "$1" 2>&1 | grep -E 'wrote|Error|Traceback|invalid' || true
win=$(echo "$out" | sed -e 's#^C:#/mnt/c#' -e 's#\\#/#g')
python3 -c "
from PIL import Image
im = Image.open('$win'); im.thumbnail((900, 900)); im.save('$2')
print('preview', '$2')"
