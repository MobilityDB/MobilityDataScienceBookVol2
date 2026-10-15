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
