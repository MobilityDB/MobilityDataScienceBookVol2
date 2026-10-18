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
