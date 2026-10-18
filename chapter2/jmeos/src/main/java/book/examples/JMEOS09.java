package book.examples;

import static functions.GeneratedFunctions.*;

import java.util.ArrayList;
import java.util.List;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import book.examples.utils.SizeOfBox;
import book.examples.utils.SizeOfBox.option;
import book.examples.utils.TripsInTile;
import functions.MeosErrorHandler;
import functions.GeneratedFunctions;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import types.boxes.STBox;

// The spatial tiling of chapter 2 (Sect. Spatial tiles), with the listings in order
public class JMEOS09 {

	public static void main(String[] args) throws Exception {
		GeneratedFunctions.meos_initialize();
		GeneratedFunctions.meos_initialize_timezone("UTC");
		GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());

		CSVRecords.setSkipHeaderLines(1);
		ArrayList<BerlinmodTripRecord> dataTrips =
				CSVRecords.readRecords(args[0], List.of(0,1,2,3,4), BerlinmodTripRecord::builder);

		// Calculate dynamically the spatial extent of the collection of trips
		Pointer extent = null;  // pointer to the STBox
		for (BerlinmodTripRecord tripRec : dataTrips)
			extent = tspatial_extent_transfn(extent, tripRec.getTrip());
		Pointer tripSpatialExtent = stbox_get_space(extent);
		System.out.println(stbox_out(tripSpatialExtent, 6));

		// bin sizes
		float xBinSize = 5000.0f;
		float yBinSize = 5000.0f;
		float zBinSize = 0.0f; // We do not use the z coordinate
		Pointer sOrigin = geom_in("SRID=3857;Point(0 0)", -1);
		Runtime runtime = Runtime.getSystemRuntime();
		Pointer noSpaceTilesPtr = Memory.allocate(runtime, Integer.BYTES);
		Pointer spaceTiles = stbox_space_tiles(
				tripSpatialExtent, xBinSize, yBinSize, zBinSize,
				sOrigin, true, noSpaceTilesPtr);
		int tilesQty = noSpaceTilesPtr.getInt(0);

		final long STBOX_SIZE = SizeOfBox.calculate(STBox.class, option.sizeof);
		System.out.println("STBOX_SIZE = " + STBOX_SIZE);
		ArrayList<TripsInTile> tilePointers = new ArrayList<>();
		for (int i = 0; i < tilesQty; i++) {
			TripsInTile auxi = new TripsInTile(i, spaceTiles.slice((long) i * STBOX_SIZE));
			tilePointers.add(auxi);
		}
		System.out.printf("Created %d spatial tiles.%n", tilesQty);
		for (TripsInTile tilePointer : tilePointers)
			System.out.printf("Tile %2d: %s%n", tilePointer.getId(),
					stbox_out(tilePointer.getTilePtr(), 0));

		for (TripsInTile tilePointer : tilePointers) {
			System.out.printf("Tile %d <- Trips ", tilePointer.getId());
			for (BerlinmodTripRecord tripRec : dataTrips) {
				Pointer trip = tripRec.getTrip();
				Pointer split = tgeo_at_stbox(trip, tilePointer.getTilePtr(), false);
				if (split != null) {
					System.out.printf("%d ", tripRec.getId());
					tilePointer.incrementCount();
					tilePointer.addDistance(tpoint_length(split, true));
					tilePointer.addDuration(temporal_duration(split, false));
				}
			}
			System.out.println();
		}
		for (TripsInTile tilePointer : tilePointers) {
			String tboxStr = stbox_out(tilePointer.getTilePtr(), 0);
			if (tilePointer.getCount() > 0)
				System.out.printf(
						"Tile: %d, Box: %s, Count: %d, Duration: %s, Distance (Km): %.3f%n",
						tilePointer.getId(), tboxStr, tilePointer.getCount(),
						pg_interval_out(tilePointer.getDuration()),
						tilePointer.getDistance() / 1000);
			else
				System.out.printf("Tile: %d, Box: %s, Count: %d%n",
						tilePointer.getId(), tboxStr, tilePointer.getCount());
		}
		GeneratedFunctions.meos_finalize();
	}
}
