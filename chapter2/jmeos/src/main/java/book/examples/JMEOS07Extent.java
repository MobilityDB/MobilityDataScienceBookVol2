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

package book.examples;

import static functions.GeneratedFunctions.*;

import java.util.ArrayList;
import java.util.List;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import functions.MeosErrorHandler;
import functions.GeneratedFunctions;
import jnr.ffi.Pointer;

// The extent aggregation of chapter 2 (Sect. Temporal Aggregation of JMEOS), printing the
// instants and the STBox of the first two trips and the extent after each of them
public class JMEOS07Extent {

	public static void main(String[] args) throws Exception {
		GeneratedFunctions.meos_initialize();
		GeneratedFunctions.meos_initialize_timezone("UTC");
		GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());

		CSVRecords.setSkipHeaderLines(1);
		ArrayList<BerlinmodTripRecord> dataTrips =
				CSVRecords.readRecords(args[0], List.of(0,1,2,3,4), BerlinmodTripRecord::builder);

		// Variable for keeping current aggregate state
		Pointer extent = null;  // STBox
		int k = 0;
		for (BerlinmodTripRecord tripRec : dataTrips) {
			if (k < 2) {
				Pointer trip = tripRec.getTrip();
				int n = temporal_num_instants(trip);
				System.out.printf("Trip %d: %d instants%n", tripRec.getId(), n);
				for (int i = 1; i <= n; i++)
					if (i <= 3 || i > n - 2)
						System.out.println(tspatial_as_text(temporal_instant_n(trip, i), 15));
				System.out.println("STBox: " + stbox_out(tspatial_to_stbox(trip), 6));
			}
			// update the extent with the STBox of the current trip
			extent = tspatial_extent_transfn(extent, tripRec.getTrip());
			if (k < 2)
				System.out.println("extent= " + stbox_out(extent, 6));
			k++;
		}
		if (extent != null)
			System.out.println("Final extent: " + stbox_out(extent, 6));
		GeneratedFunctions.meos_finalize();
	}
}
