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

public class CommuneRecord {
	private int id;
	private String name;
	private int population;
	private Pointer geom;
	private String geomAsString;
		
	private CommuneRecord() {
	}
	
	public static CommuneRecord builder(String aLine[], List<Integer> colPositions)
    {
		CommuneRecord auxi = new CommuneRecord();
		
		// Order of strings: id name population geom
		try {
			auxi.id= Integer.valueOf(aLine[colPositions.get(0)]);
			auxi.name= aLine[colPositions.get(1)];
			auxi.population= Integer.valueOf(aLine[colPositions.get(2)]);
			auxi.geom = geom_in(aLine[colPositions.get(3)], -1);
			auxi.geomAsString=aLine[colPositions.get(3)];
			 if (auxi.geom == null) {
                 System.out.println("Failed to parse geometry for commune " + auxi.name);
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
	

	public Pointer getGeom() {
		return geom;
	}
	
	public String getName() {
		return name;
	}
	
	@Override
	public String toString() {
		return String.format("%d %s %d %s", id, name, population, geomAsString);
	}
}
