/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

package book.examples.utils;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

// Size and alignment of a MEOS C structure, as printed in the chapter
public class SizeOfBox {

	public enum option { sizeof, _Alignof };

	public static int calculate(Class<?> type, option requirement)
			throws IOException, InterruptedException {

		String cType = type.getSimpleName();
		String req = requirement.toString();

		// Produce an extra \ because echo consumes one of them
		String cProgram =
				String.format(
					"#include <stdio.h>\n" +
					"#include <meos.h>\n" +
					"int main(void) {\n" +
					"    printf(\"%%zu\\\\n\", %s(%s));\n" +
					"    return 0;\n" +
					"}\n", req, cType);

		String commandLine = String.format(
			"echo '%s' | gcc -x c -o /tmp/SizeOfBox - " +
			"&& /tmp/SizeOfBox; rm -f /tmp/SizeOfBox",
			cProgram
		);

		Process process = new ProcessBuilder("sh", "-c", commandLine)
				.redirectErrorStream(true)
				.start();

		StringBuilder output = new StringBuilder();
		try (BufferedReader reader =
				new BufferedReader(
					new InputStreamReader(process.getInputStream()))) {
			String line;
			while ((line = reader.readLine()) != null) {
				output.append(line).append("\n");
			}
		}

		int exitCode = process.waitFor();

		if (exitCode != 0) {
			throw new RuntimeException(
				String.format("Error calculating %s(%s):\n", req, cType) + output
			);
		}
		return Integer.parseInt(output.toString().trim());
	}
}
