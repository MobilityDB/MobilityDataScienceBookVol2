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
