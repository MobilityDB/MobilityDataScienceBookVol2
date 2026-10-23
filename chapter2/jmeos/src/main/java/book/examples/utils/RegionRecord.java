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

import static functions.GeneratedFunctions.geom_in; 
import java.util.List;
import jnr.ffi.Pointer;

public class RegionRecord {
	private String name;
	private Pointer geom;
	private String geomAsString;
		
	private RegionRecord() {
	}
	
	public static RegionRecord builder(String aLine[], List<Integer> colPositions)
    {
		RegionRecord auxi = new RegionRecord();
		
		// Order of strings: id name population geom
		try {
			auxi.name= aLine[colPositions.get(0)];
			auxi.geom = geom_in(aLine[colPositions.get(1)], -1);
			auxi.geomAsString=aLine[colPositions.get(1)];
			if (auxi.geom == null) {
                 System.out.println("Failed to parse geometry for region " + auxi.name);
                 return null;
             }
			
			return auxi;
		}
		catch (Exception e) {
			System.err.println("Invalid Record ignored " +  
					String.join(", ", aLine)  + e);
			return null;
		}
	}
	
	public String getName() {
		return name;
	}
	
	public Pointer getGeom() {
		return geom;
	}
	
	@Override
	public String toString() {
		return String.format("%s %s", name, geomAsString);
	}
}
