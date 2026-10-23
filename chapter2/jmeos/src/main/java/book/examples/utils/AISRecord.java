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

import java.time.OffsetDateTime;
import java.util.List;
import static functions.GeneratedFunctions.*;


public class AISRecord {
			
	private long MMSI;
	
	private OffsetDateTime t;
	private double latitude;
	private double longitude;
	private double SOG;
	
	
	
	private AISRecord() {
	}
	
	public static AISRecord builder(String[] aLine, List<Integer> colsPoistions) {
		AISRecord auxi = new AISRecord();
		
		try {
			auxi.t = pg_timestamptz_in(aLine[colsPoistions.get(0)], -1);
			auxi.MMSI= Long.valueOf(aLine[colsPoistions.get(1)]);
			auxi.latitude= Double.valueOf(aLine[colsPoistions.get(2)]);
			auxi.longitude= Double.valueOf(aLine[colsPoistions.get(3)]);
			auxi.SOG= Double.valueOf(aLine[colsPoistions.get(4)]);
			return auxi;
		}
		catch (Exception e) {
        // System.err.println("Invalid Record ignored " +  
		//	String.join(", ", aLine)  + e);
			return null;
		}
		

	}
	
	
	
	@Override
	public String toString() {
		return String.format("%s %s %s %s %s", t, MMSI, latitude, longitude, SOG);
	}
	

	public Long getMMSI() {
		return MMSI;
	}
	
	public long  getMillisec() {
		return t.toInstant().toEpochMilli();
	}
	
	public   OffsetDateTime getT() {
		return t;
	}
	
	public double  getLatitude() {
		return latitude;
	}
	
	public double  getLongitude() {
		return longitude;
	}
	
	public double  getSOG() {
		return SOG;
	}
}


