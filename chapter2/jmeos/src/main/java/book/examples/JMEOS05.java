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
import jnr.ffi.Pointer;

import static functions.GeneratedFunctions.tgeo_at_geom;
import static functions.GeneratedFunctions.tpoint_length;
import static functions.GeneratedFunctions.tpoint_minus_geom;
import java.util.ArrayList;
import java.util.List;
import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import book.examples.utils.CommuneRecord;
import book.examples.utils.RegionRecord;



public class JMEOS05 {
 
    public static void main(String[] args) throws Exception {
    	
    	 GeneratedFunctions.meos_initialize();
         GeneratedFunctions.meos_initialize_timezone("UTC");
         GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());
     	
    	
         CSVRecords.setSkipHeaderLines(1);  // skip header
    	
         // Read the CSV file into a collection.
         // First parameter absolute path of the CSV file
         // Second parameter indicate the positional columns to use when 
         // populating a CommuneRecord.
         // Last parameter the name of the fn to build a CommuneRecord. 
         ArrayList<CommuneRecord> communes = 
        	CSVRecords.readRecords("/data/brussels_communes.csv",
    		List.of(0,1,2,3), // id, name, population, geom
    		CommuneRecord::builder
		 );
    	  
    	  
         // Read the CSV file into a collection.
         // First parameter absolute path of the CSV file
         // Second parameter indicate the positional columns to use when 
         // populating a RegionRecord.
         // Last parameter the name of the fn to build a RegionRecord. 
         ArrayList<RegionRecord> regions = 
        	CSVRecords.readRecords("/data/brussels_region.csv",
      		List.of(0,1), // name geom
      		RegionRecord::builder
  		  );
         
         // the only one region in the csv is brussels
         RegionRecord brusselsRegion = regions.get(0);

         // Read the CSV file into a collection.
         // First parameter absolute path of the CSV file
         // Second parameter indicate the positional columns to use when 
         // populating a TripRecord.
         // Last parameter the name of the fn to build a TripRecord. 
         ArrayList<BerlinmodTripRecord> dataTrips = 
        	CSVRecords.readRecords("/data/berlinmod_trips.csv",
        	List.of(0,1,2,3,4),
        	BerlinmodTripRecord::builder
  		 );
      	
        
       	 double totalInside=0;
       	 double totalOutside=0;
         for (CommuneRecord cc: communes) {
        	 
        	 double d= 0;
         	 for (BerlinmodTripRecord tripRec : dataTrips) {
        		 // Clip trip to commune geometry
                 Pointer atGeom = tgeo_at_geom(tripRec.getTrip(), cc.getGeom());

                 if (atGeom != null) {
                     // Compute length of trip within commune
                     d += tpoint_length(atGeom, true) / 1000.0;
                 }
                 
                 // Compute distance outside Brussels region
            	Pointer minusGeom = tpoint_minus_geom(tripRec.getTrip(), brusselsRegion.getGeom());

            	if (minusGeom != null) {
                   totalOutside += tpoint_length(minusGeom, true) / 1000.0;
            	}
         	 }
         	 System.out.printf("Total length inside %s: %g km%n", cc.getName(), d);
             totalInside+= d;
         }
         System.out.printf("Total length inside %s: %g km%n", brusselsRegion.getName(), totalInside);
         System.out.printf("Total length outside %s: %g km%n", brusselsRegion.getName(), totalOutside/communes.size());
          

  
  
        GeneratedFunctions.meos_finalize();
    }

}
