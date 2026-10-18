package book.examples;

import static functions.GeneratedFunctions.*;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import book.examples.utils.SizeOfBox;
import book.examples.utils.SizeOfBox.option;
import book.examples.utils.TripsInSpeedTimeTile;
import functions.MeosErrorHandler;
import functions.GeneratedFunctions;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import types.boxes.TBox;

// The speed-time tiling of chapter 2 (Sect. Speed-time tiles), with the listings in order
public class JMEOS08 {

	public static void main(String[] args) throws Exception {
		GeneratedFunctions.meos_initialize();
		GeneratedFunctions.meos_initialize_timezone("UTC");
		GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());

		CSVRecords.setSkipHeaderLines(1);
		ArrayList<BerlinmodTripRecord> dataTrips =
				CSVRecords.readRecords(args[0], List.of(0,1,2,3,4), BerlinmodTripRecord::builder);

		Pointer temporalExtent = null;
		float maxSpeed = 0;
		for (BerlinmodTripRecord tripRec : dataTrips) {
			// Get the span of the trip
			Pointer currentSpanPtr = temporal_to_tstzspan(tripRec.getTrip());
			// Recalculate the temporal extent
			temporalExtent = span_extent_transfn(temporalExtent, currentSpanPtr);
			// Compute max speed
			Pointer speed = tpoint_speed(tripRec.getTrip(), true);
			float currentSpeed = (float) tfloat_max_value(speed);
			if (maxSpeed < currentSpeed)
				maxSpeed = currentSpeed;
		}
		// Build float span for the speed from 0 to the max calculated speed
		Pointer speedSpan = GeneratedFunctions.floatspan_make(0.0f, maxSpeed, true, true);
		// Build the speed-time TBox
		Pointer speedTimeExtent = GeneratedFunctions.tbox_make(speedSpan, temporalExtent);
		System.out.println(tbox_out(speedTimeExtent, 6));

		// bin sizes
		float speedBinSize = 10.0f;
		Pointer temporalBinSize = pg_interval_in("1 day", -1);
		// origins
		double speedOrigin = 0.0;
		OffsetDateTime startingTimestamp = GeneratedFunctions.tstzspan_lower(temporalExtent);
		int pgDate = GeneratedFunctions.timestamptz_to_date(startingTimestamp);
		OffsetDateTime temporalOrigin = GeneratedFunctions.date_to_timestamptz(pgDate);

		Runtime runtime = Runtime.getSystemRuntime();
		Pointer speedTimeTilesQtyPtr = Memory.allocate(runtime, Integer.BYTES);
		Pointer speedTimeTiles = tfloatbox_value_time_tiles(speedTimeExtent, speedBinSize,
				temporalBinSize, speedOrigin, temporalOrigin, true, speedTimeTilesQtyPtr);
		int tilesQty = speedTimeTilesQtyPtr.getInt(0);

		final long TBOX_SIZE = SizeOfBox.calculate(TBox.class, option.sizeof);
		System.out.println("TBOX_SIZE = " + TBOX_SIZE);
		ArrayList<TripsInSpeedTimeTile> tilePointers = new ArrayList<>();
		for (int i = 0; i < tilesQty; i++) {
			TripsInSpeedTimeTile auxi =
					new TripsInSpeedTimeTile(i, speedTimeTiles.slice((long) i * TBOX_SIZE));
			tilePointers.add(auxi);
		}
		for (TripsInSpeedTimeTile tilePointer : tilePointers)
			System.out.printf("Tile %2d: %s%n", tilePointer.getId(),
					tbox_out(tilePointer.getTilePtr(), 0));

		System.out.printf("Created %d Speed Time tiles.%n", tilesQty);
		System.out.println("Processing records");
		for (TripsInSpeedTimeTile tilePointer : tilePointers) {
			System.out.printf("Tile %d <- Trips ", tilePointer.getId());
			for (BerlinmodTripRecord tripRec : dataTrips) {
				Pointer trip = tripRec.getTrip();
				Pointer speed = tpoint_speed(trip, true);
				Pointer split = tnumber_at_tbox(speed, tilePointer.getTilePtr());
				if (split != null) {
					System.out.printf("%d ", tripRec.getId());
					tilePointer.incrementCount();
					tilePointer.addDuration(temporal_duration(split, false));
				}
			}
			System.out.println();
		}
		System.out.println("-----------------------------------");
		System.out.println("Speed-time tiles summarization");
		System.out.println("-----------------------------------");
		for (TripsInSpeedTimeTile tilePointer : tilePointers) {
			String tboxStr = tbox_out(tilePointer.getTilePtr(), 0);
			if (tilePointer.getCount() > 0)
				System.out.printf("Tile: %d, Box: %s, Count: %d, Duration: %s%n",
						tilePointer.getId(), tboxStr, tilePointer.getCount(),
						pg_interval_out(tilePointer.getDuration()));
			else
				System.out.printf("Tile: %d, Box: %s, Count: %d%n",
						tilePointer.getId(), tboxStr, tilePointer.getCount());
		}
		GeneratedFunctions.meos_finalize();
	}
}
