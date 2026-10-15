package book.examples;

import static functions.functions.*;

import java.time.OffsetDateTime;
import java.util.ArrayList;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.SizeOfBox;
import book.examples.utils.SizeOfBox.option;
import book.examples.utils.TripsInSpeedTimeTile;
import functions.functions;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import types.boxes.TBox;

// The speed-time tiling of JMEOS08, with the temporal bin size as a parameter
public class SpeedTimeTiling {

	public static ArrayList<TripsInSpeedTimeTile> tiles(
			ArrayList<BerlinmodTripRecord> dataTrips, String binSize) throws Exception {
		Pointer temporalExtent = null;
		float maxSpeed = 0;
		for (BerlinmodTripRecord tripRec : dataTrips) {
			Pointer currentSpanPtr = temporal_to_tstzspan(tripRec.getTrip());
			temporalExtent = span_extent_transfn(temporalExtent, currentSpanPtr);
			Pointer speed = tpoint_speed(tripRec.getTrip());
			float currentSpeed = (float) tfloat_max_value(speed);
			if (maxSpeed < currentSpeed)
				maxSpeed = currentSpeed;
		}
		Pointer speedSpan = functions.floatspan_make(0.0f, maxSpeed, true, true);
		Pointer speedTimeExtent = functions.tbox_make(speedSpan, temporalExtent);
		System.out.println(tbox_out(speedTimeExtent, 6));

		float speedBinSize = 10.0f;
		Pointer temporalBinSize = pg_interval_in(binSize, -1);
		double speedOrigin = 0.0;
		OffsetDateTime startingTimestamp = functions.tstzspan_lower(temporalExtent);
		int pgDate = functions.timestamptz_to_date(startingTimestamp);
		OffsetDateTime temporalOrigin = functions.date_to_timestamptz(pgDate);

		Runtime runtime = Runtime.getSystemRuntime();
		Pointer speedTimeTilesQtyPtr = Memory.allocate(runtime, Integer.BYTES);
		Pointer speedTimeTiles = tfloatbox_value_time_tiles(speedTimeExtent, speedBinSize,
				temporalBinSize, speedOrigin, temporalOrigin, speedTimeTilesQtyPtr);
		int tilesQty = speedTimeTilesQtyPtr.getInt(0);
		System.out.printf("Created %d Speed Time tiles.%n", tilesQty);

		final long TBOX_SIZE = SizeOfBox.calculate(TBox.class, option.sizeof);
		ArrayList<TripsInSpeedTimeTile> tilePointers = new ArrayList<>();
		for (int i = 0; i < tilesQty; i++)
			tilePointers.add(new TripsInSpeedTimeTile(i,
					speedTimeTiles.slice((long) i * TBOX_SIZE)));

		for (TripsInSpeedTimeTile tilePointer : tilePointers) {
			for (BerlinmodTripRecord tripRec : dataTrips) {
				Pointer speed = tpoint_speed(tripRec.getTrip());
				Pointer split = tnumber_at_tbox(speed, tilePointer.getTilePtr());
				// in JMEOS08, when a trip has a portion in the tile
				if (split != null) {
					tilePointer.incrementCount();
					tilePointer.addDuration(temporal_duration(split, false));
					tilePointer.addTripId(tripRec.getId());
				}
			}
		}
		return tilePointers;
	}
}
