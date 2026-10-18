package book.examples.utils;

import static functions.GeneratedFunctions.*;

import java.util.Set;
import java.util.TreeSet;

import jnr.ffi.Pointer;

public class TripsInSpeedTimeTile {
	// tile information
	private int tileID;
	private Pointer tilePtr;

	// aggregated information of partial trips in the tile
	private int count = 0;
	private Pointer duration = null;  // Interval
	private Set<Integer> tripIds = new TreeSet<>();  // trips in the tile

	public TripsInSpeedTimeTile(int newTileID, Pointer newTilePtr) {
		tileID = newTileID;
		tilePtr = newTilePtr;
	}

	public void incrementCount() {
		count++;
	}

	public void addDuration(Pointer newDuration) {
		if (duration == null) {
			duration = newDuration;
		}
		else {
			duration = add_interval_interval(newDuration, duration);
		}
	}

	public void addTripId(int tripId) {
		tripIds.add(tripId);
	}

	// getters
	public int getId() {
		return tileID;
	}

	public Pointer getTilePtr() {
		return tilePtr;
	}

	public int getCount() {
		return count;
	}

	public Pointer getDuration() {
		return duration;
	}

	public Set<Integer> getTripIds() {
		return tripIds;
	}
}
