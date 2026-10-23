#
# This MobilityDB code is provided under The PostgreSQL License.
# Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
# contributors
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written
# agreement is hereby granted, provided that the above copyright notice and
# this paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
# AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

"""Capture the pages of the Spark History Server that the chapter shows, with headless Chrome:
one PNG per page, at twice the pixel density of the window.

    python history_server.py <application id> <out>

<application id> is the identifier of the running application of the notebook that queries the
Citi Bike tables (application_..., as the History Server lists it under the incomplete
applications) after Query Q1 has run; the pages are incomplete.png and incomplete2.png (the completed and the incomplete applications),
thesparkapp.png (the jobs of the application), completedquery.png (its SQL queries),
executors.png (its executors) and sqldetails.png (the plan of its fourth SQL query). CHROME is
the Chrome or Chromium executable (default google-chrome) and HISTORY the address of the History
Server of docker-compose-nozeppelin.yml (default http://localhost:18080).
"""
import os
import subprocess
import sys

CHROME = os.environ.get("CHROME", "google-chrome")
APP, OUT = sys.argv[1], os.path.abspath(sys.argv[2])
H = os.environ.get("HISTORY", "http://localhost:18080")
PAGES = [
    ("incomplete", f"{H}/", 1150, 420),
    ("incomplete2", f"{H}/?showIncomplete=true", 1150, 420),
    ("thesparkapp", f"{H}/history/{APP}/jobs/", 1150, 1000),
    ("completedquery", f"{H}/history/{APP}/SQL/", 1150, 560),
    ("executors", f"{H}/history/{APP}/executors/", 1300, 1130),
    ("sqldetails", f"{H}/history/{APP}/SQL/execution/?id=3", 1150, 2400),
]
os.makedirs(OUT, exist_ok=True)
for name, url, w, h in PAGES:
    subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=2",
                    f"--window-size={w},{h}", "--virtual-time-budget=8000",
                    f"--screenshot={OUT}/{name}.png", url],
                   check=True, capture_output=True)
    print(name)
