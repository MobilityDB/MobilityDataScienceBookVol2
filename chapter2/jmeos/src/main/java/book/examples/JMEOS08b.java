package book.examples;

import static functions.functions.*;

import java.util.ArrayList;
import java.util.List;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import book.examples.utils.TripsInSpeedTimeTile;
import functions.MeosErrorHandler;
import functions.functions;

// Exercise: speed-time tiles with an 8-hour temporal granularity
public class JMEOS08b {

	public static void main(String[] args) throws Exception {
		functions.meos_initialize();
		functions.meos_initialize_timezone("UTC");
		functions.meos_initialize_error_handler(new MeosErrorHandler());

		CSVRecords.setSkipHeaderLines(1);
		ArrayList<BerlinmodTripRecord> dataTrips =
				CSVRecords.readRecords(args.length > 0 ? args[0] : "/data/berlinmod_trips.csv",
				List.of(0,1,2,3,4),
				BerlinmodTripRecord::builder);

		ArrayList<TripsInSpeedTimeTile> tilePointers =
				SpeedTimeTiling.tiles(dataTrips, "8 hours");

		for (TripsInSpeedTimeTile tilePointer : tilePointers) {
			String tboxStr = tbox_out(tilePointer.getTilePtr(), 0);
			if (tilePointer.getCount() > 0)
				System.out.printf("Tile: %d, %s, Count: %d, Duration: %s%n",
						tilePointer.getId(), tboxStr, tilePointer.getCount(),
						pg_interval_out(tilePointer.getDuration()));
			else
				System.out.printf("Tile: %d, %s, Count: 0%n", tilePointer.getId(), tboxStr);
		}
		functions.meos_finalize();
	}
}
