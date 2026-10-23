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

import java.time.OffsetDateTime;
import java.util.ArrayList;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.SizeOfBox;
import book.examples.utils.SizeOfBox.option;
import book.examples.utils.TripsInSpeedTimeTile;
import functions.GeneratedFunctions;
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
			Pointer speed = tpoint_speed(tripRec.getTrip(), true);
			float currentSpeed = (float) tfloat_max_value(speed);
			if (maxSpeed < currentSpeed)
				maxSpeed = currentSpeed;
		}
		Pointer speedSpan = GeneratedFunctions.floatspan_make(0.0f, maxSpeed, true, true);
		Pointer speedTimeExtent = GeneratedFunctions.tbox_make(speedSpan, temporalExtent);
		System.out.println(tbox_out(speedTimeExtent, 6));

		float speedBinSize = 10.0f;
		Pointer temporalBinSize = pg_interval_in(binSize, -1);
		double speedOrigin = 0.0;
		OffsetDateTime startingTimestamp = GeneratedFunctions.tstzspan_lower(temporalExtent);
		int pgDate = GeneratedFunctions.timestamptz_to_date(startingTimestamp);
		OffsetDateTime temporalOrigin = GeneratedFunctions.date_to_timestamptz(pgDate);

		Runtime runtime = Runtime.getSystemRuntime();
		Pointer speedTimeTilesQtyPtr = Memory.allocate(runtime, Integer.BYTES);
		Pointer speedTimeTiles = tfloatbox_value_time_tiles(speedTimeExtent, speedBinSize,
				temporalBinSize, speedOrigin, temporalOrigin, true, speedTimeTilesQtyPtr);
		int tilesQty = speedTimeTilesQtyPtr.getInt(0);
		System.out.printf("Created %d Speed Time tiles.%n", tilesQty);

		final long TBOX_SIZE = SizeOfBox.calculate(TBox.class, option.sizeof);
		ArrayList<TripsInSpeedTimeTile> tilePointers = new ArrayList<>();
		for (int i = 0; i < tilesQty; i++)
			tilePointers.add(new TripsInSpeedTimeTile(i,
					speedTimeTiles.slice((long) i * TBOX_SIZE)));

		for (TripsInSpeedTimeTile tilePointer : tilePointers) {
			for (BerlinmodTripRecord tripRec : dataTrips) {
				Pointer speed = tpoint_speed(tripRec.getTrip(), true);
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
