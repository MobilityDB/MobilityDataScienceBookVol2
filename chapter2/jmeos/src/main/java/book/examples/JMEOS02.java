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


import functions.MeosErrorHandler;
import functions.GeneratedFunctions; 
import static functions.GeneratedFunctions.temporal_num_instants;
import static functions.GeneratedFunctions.tpoint_length;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import book.examples.utils.AISReadRecords;
import book.examples.utils.AISRecord;
import book.examples.utils.ShipRecord;


public class JMEOS02 {
  
	
    public static void main(String[] args) throws Exception {
     	
     	 GeneratedFunctions.meos_initialize();
         GeneratedFunctions.meos_initialize_timezone("UTC");
         GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());


    	// read CSV file 
    	// the information are in chronologically ascendant order, not sorted by MMSI.
    	// A hashmap is built for associating each MMSI with all its AIS records.
    	 HashMap<Long, ArrayList<AISRecord>> data = AISReadRecords.readRecords("/data/aisdk-2024-03-04.csv",
    			 List.of(0,1,2,3,4));
 
    	
    	 
    	// Once the total AIS records are read we can calculate 
    	// temporal attributes trip and SOG for each MMSI
     	ArrayList<ShipRecord> tripRecords = new ArrayList<>();

      	for (Map.Entry<Long, ArrayList<AISRecord>> aisRecMMSI : data.entrySet()) {
     		 Long key = aisRecMMSI.getKey();
     		 ArrayList<AISRecord> itsAISRecords = aisRecMMSI.getValue();
     		 
     		 System.out.println("key= " + key);
     		 
     		 ShipRecord auxi = ShipRecord.builder(aisRecMMSI.getKey(), itsAISRecords ) ;
     		 
      		tripRecords.add( auxi );
     		
     	}
        
     	
     	for (ShipRecord trip : tripRecords) {
     		 System.out.printf("Trip %d-> Number of instants: %d, Distance travelled %f%n",
                     trip.getMMSI(), temporal_num_instants(trip.getTrip()), 
                     tpoint_length(trip.getTrip(), true));
     		 
     		 
     		 System.out.printf(" Simplified Trip by Douglas-Peucker %d-> Number of instants: %d, Distance travelled %f%n%n",
                     trip.getMMSI(), temporal_num_instants(trip.getSimplifiedTrip()), tpoint_length(trip.getSimplifiedTrip(), true));
 
     	}

     	// 
        GeneratedFunctions.meos_finalize();
    }
}