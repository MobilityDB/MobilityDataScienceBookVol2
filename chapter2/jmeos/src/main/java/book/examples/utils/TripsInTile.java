package book.examples.utils;

import static functions.GeneratedFunctions.*;

import jnr.ffi.Pointer;

// The TripsInTile class printed in chapter 2 (Sect. Spatial tiles)
public class TripsInTile {

	private int tileID;
	private Pointer tilePtr;

	// Aggregated information for trips associated with the tile
	private int count = 0;
	private Pointer duration = null;  // Interval
	private double distance = 0.0;

	public TripsInTile(int newTileID, Pointer newTilePtr) {
		tileID = newTileID;
		tilePtr = newTilePtr;
	}

	public int getId() {
		return tileID;
	}

	public void incrementCount() {
		count++;
	}

	public void addDistance(double newDistance) {
		this.distance += newDistance;
	}

	public void addDuration(Pointer newDuration) {
		if (duration == null) {
			duration = newDuration;
		}
		else {
			duration = add_interval_interval(newDuration, duration);
		}
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

	public double getDistance() {
		return distance;
	}
}
