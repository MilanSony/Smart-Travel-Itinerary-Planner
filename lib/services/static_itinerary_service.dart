import 'package:flutter/material.dart';
import '../models/itinerary_model.dart'; // Make sure you have the Itinerary model file from our previous steps

class StaticItineraryService {
  // This is our expanded pre-written "database" of itineraries.
  static final Map<String, Itinerary> _itineraries = {
    // --- GOA (5 DAYS) ---
    'goa': Itinerary(
      destination: 'Goa',
      title: 'A Week of Sun, Sand, and Spice',
      dayPlans: [
        DayPlan(
          dayTitle: 'Day 1: Arrival & Anjuna Vibes',
          description: 'Settle in and explore the vibrant flea markets and iconic beach shacks of North Goa.',
          activities: [
            Activity(time: '2:00 PM', title: 'Check-in & Relax', description: 'Arrive at your hotel in North Goa and unwind.', icon: Icons.hotel_outlined),
            Activity(time: '5:00 PM', title: 'Anjuna Flea Market', description: 'Discover unique souvenirs, clothes, and local crafts.', icon: Icons.shopping_bag_outlined),
            Activity(time: '8:00 PM', title: 'Dinner at Curlies', description: 'Enjoy a classic Goan dinner with stunning sea views at this legendary beach shack.', icon: Icons.restaurant_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 2: Historical Old Goa',
          description: 'Step back in time and explore the magnificent churches of Old Goa, a UNESCO World Heritage site.',
          activities: [
            Activity(time: '10:00 AM', title: 'Basilica of Bom Jesus', description: 'Visit the iconic church holding the mortal remains of St. Francis Xavier.', icon: Icons.church_outlined),
            Activity(time: '1:00 PM', title: 'Lunch in Panjim', description: 'Savor authentic Goan-Portuguese cuisine in the charming capital city.', icon: Icons.restaurant_menu_outlined),
            Activity(time: '3:00 PM', title: 'Fontainhas Latin Quarter', description: 'Stroll through the colorful, picturesque streets of Panjim’s old Latin Quarter.', icon: Icons.camera_alt_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 3: South Goa Serenity',
          description: 'Experience the tranquil and pristine beaches of South Goa, a perfect escape from the crowds.',
          activities: [
            Activity(time: '11:00 AM', title: 'Palolem Beach', description: 'Relax on the crescent-shaped beach known for its calm waters and scenic beauty.', icon: Icons.beach_access_outlined),
            Activity(time: '1:00 PM', title: 'Seafood Lunch at a Shack', description: 'Enjoy fresh, delicious seafood at a local beachside restaurant.', icon: Icons.set_meal_outlined),
            Activity(time: '4:00 PM', title: 'Dolphin Sighting Trip', description: 'Take a boat trip for a chance to see dolphins playing in the Arabian Sea.', icon: Icons.waves_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 4: Spice Plantations & Nature',
          description: 'A day dedicated to the lush nature and aromatic spices of inland Goa.',
          activities: [
            Activity(time: '10:00 AM', title: 'Sahakari Spice Farm', description: 'Take a guided tour, learn about local spices, and enjoy a traditional Goan lunch.', icon: Icons.eco_outlined),
            Activity(time: '3:00 PM', title: 'Dudhsagar Falls Viewpoint', description: 'Trek or take a jeep safari to witness the majestic "Sea of Milk" waterfall.', icon: Icons.waterfall_chart_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 5: Calangute & Baga Beach Fun',
          description: 'Enjoy the most famous beaches of North Goa, with plenty of water sports and activities.',
          activities: [
            Activity(time: '11:00 AM', title: 'Water Sports at Baga Beach', description: 'Try parasailing, jet-skiing, or a banana boat ride.', icon: Icons.sports_kabaddi_outlined),
            Activity(time: '2:00 PM', title: 'Lunch at Britto\'s', description: 'Dine at another iconic beach shack on Baga, known for its lively atmosphere.', icon: Icons.restaurant_outlined),
            Activity(time: '5:00 PM', title: 'Relax at Calangute Beach', description: 'Known as the "Queen of Beaches," perfect for a relaxing evening stroll.', icon: Icons.stroller_outlined),
          ],
        ),
      ],
    ),

    // --- JAIPUR (5 DAYS) ---
    'jaipur': Itinerary(
      destination: 'Jaipur',
      title: 'The Royal Pink City Expedition',
      dayPlans: [
        DayPlan(
          dayTitle: 'Day 1: Forts and Palaces',
          description: 'Explore the majestic forts that stand guard over the city and the royal residence.',
          activities: [
            Activity(time: '10:00 AM', title: 'Amber Fort (Amer Fort)', description: 'Ascend the fort on an elephant or jeep and explore its magnificent palaces.', icon: Icons.fort_outlined),
            Activity(time: '2:00 PM', title: 'City Palace', description: 'Visit the royal residence, a beautiful complex of courtyards, gardens, and museums.', icon: Icons.place_outlined),
            Activity(time: '5:00 PM', title: 'Hawa Mahal Photo Stop', description: 'Photograph the iconic "Palace of Winds" with its 953 intricate windows.', icon: Icons.camera_alt_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 2: Astronomy & Local Bazaars',
          description: 'Discover ancient scientific instruments and dive into the vibrant local markets.',
          activities: [
            Activity(time: '11:00 AM', title: 'Jantar Mantar', description: 'Explore the UNESCO site, a collection of nineteen architectural astronomical instruments.', icon: Icons.public_outlined),
            Activity(time: '2:00 PM', title: 'Lunch at a Local Eatery', description: 'Taste authentic Rajasthani thali in the heart of the city.', icon: Icons.restaurant_menu_outlined),
            Activity(time: '4:00 PM', title: 'Shopping at Johari Bazaar', description: 'Hunt for traditional jewelry, textiles, and handicrafts in the bustling market.', icon: Icons.shopping_bag_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 3: Nahargarh Sunset & Stepwell',
          description: 'Get panoramic views of the city and discover a hidden architectural gem.',
          activities: [
            Activity(time: '3:00 PM', title: 'Panna Meena Ka Kund', description: 'Visit the ancient, symmetrical stepwell for incredible photo opportunities.', icon: Icons.stairs_outlined),
            Activity(time: '5:00 PM', title: 'Nahargarh Fort at Sunset', description: 'Drive up to the fort for the most breathtaking sunset view over Jaipur.', icon: Icons.wb_sunny_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 4: Artistic Side of Jaipur',
          description: 'Explore the local crafts and artistry that make Jaipur famous.',
          activities: [
            Activity(time: '11:00 AM', title: 'Block Printing Workshop', description: 'Participate in a hands-on workshop to learn the traditional art of block printing.', icon: Icons.brush_outlined),
            Activity(time: '2:00 PM', title: 'Albert Hall Museum', description: 'Admire the stunning Indo-Saracenic architecture and its vast collection of artifacts.', icon: Icons.museum_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 5: Elephants & Departure',
          description: 'A final, memorable experience before you depart.',
          activities: [
            Activity(time: '10:00 AM', title: 'Elefantastic Elephant Sanctuary', description: 'Spend time with rescued elephants in an ethical sanctuary, where you can feed and bathe them.', icon: Icons.pets_outlined),
            Activity(time: '1:00 PM', title: 'Farewell Lunch', description: 'Enjoy a final Rajasthani meal before heading to the airport.', icon: Icons.restaurant_outlined),
          ],
        ),
      ],
    ),

    // --- DELHI (5 DAYS) ---
    'delhi': Itinerary(
      destination: 'Delhi',
      title: 'A Tale of Two Cities: Old & New',
      dayPlans: [
        DayPlan(
          dayTitle: 'Day 1: Imperial New Delhi',
          description: 'Discover the grand avenues and monuments of Lutyens\' Delhi.',
          activities: [
            Activity(time: '10:00 AM', title: 'Humayun\'s Tomb', description: 'Visit the stunning garden tomb that inspired the Taj Mahal.', icon: Icons.architecture_outlined),
            Activity(time: '1:00 PM', title: 'India Gate & Kartavya Path', description: 'Pay respects at the war memorial arch and stroll along the grand central axis.', icon: Icons.location_city_outlined),
            Activity(time: '4:00 PM', title: 'Qutub Minar Complex', description: 'Marvel at the towering minaret and surrounding ancient ruins.', icon: Icons.account_balance_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 2: Mughal Majesty in Old Delhi',
          description: 'Journey through the historic heart of the city, filled with ancient forts and bustling bazaars.',
          activities: [
            Activity(time: '10:00 AM', title: 'Red Fort (Lal Qila)', description: 'Explore the massive red sandstone fort, the main residence of Mughal emperors.', icon: Icons.fort_outlined),
            Activity(time: '1:00 PM', title: 'Rickshaw Ride in Chandni Chowk', description: 'Experience the chaotic charm and street food of one of India\'s oldest markets.', icon: Icons.pedal_bike_outlined),
            Activity(time: '3:00 PM', title: 'Jama Masjid', description: 'Visit one of the largest mosques in India, an architectural marvel.', icon: Icons.mosque_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 3: Spiritual & Cultural Heart',
          description: 'Experience the diverse spiritual and cultural fabric of Delhi.',
          activities: [
            Activity(time: '11:00 AM', title: 'Lotus Temple', description: 'Visit the beautiful Baháʼí House of Worship, famous for its flowerlike shape.', icon: Icons.local_florist_outlined),
            Activity(time: '2:00 PM', title: 'Akshardham Temple', description: 'Explore the sprawling complex known for its intricate carvings, exhibitions, and boat ride.', icon: Icons.temple_hindu_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 4: Art, Crafts, and Shopping',
          description: 'Indulge in the artistic and modern side of the city.',
          activities: [
            Activity(time: '12:00 PM', title: 'Dilli Haat', description: 'Shop for handicrafts from all over India and enjoy regional cuisines in an open-air market.', icon: Icons.storefront_outlined),
            Activity(time: '4:00 PM', title: 'Khan Market', description: 'Explore the upscale market for its bookstores, boutiques, and trendy cafes.', icon: Icons.shopping_cart_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 5: A Peaceful Farewell',
          description: 'A relaxing morning before departure.',
          activities: [
            Activity(time: '10:00 AM', title: 'Lodhi Garden', description: 'Enjoy a peaceful walk among the beautiful tombs and lush greenery.', icon: Icons.park_outlined),
            Activity(time: '12:00 PM', title: 'Farewell Brunch', description: 'Enjoy a final meal at a cafe in the Lodhi Colony area.', icon: Icons.restaurant_outlined),
          ],
        ),
      ],
    ),

    // --- BANGALORE (5 DAYS) ---
    'bangalore': Itinerary(
      destination: 'Bangalore',
      title: 'The Garden & Silicon City of India',
      dayPlans: [
        DayPlan(
          dayTitle: 'Day 1: Gardens, Palaces, and Pubs',
          description: 'Experience the blend of nature, royalty, and modern culture.',
          activities: [
            Activity(time: '10:00 AM', title: 'Lalbagh Botanical Garden', description: 'Explore the historic glass house and diverse collection of tropical plants.', icon: Icons.park_outlined),
            Activity(time: '2:00 PM', title: 'Bangalore Palace', description: 'Visit the magnificent Tudor-style palace inspired by Windsor Castle.', icon: Icons.castle_outlined),
            Activity(time: '7:00 PM', title: 'Dinner in Indiranagar', description: 'Enjoy the vibrant nightlife and breweries in one of Bangalore\'s trendiest neighborhoods.', icon: Icons.nightlife_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 2: Tech, Temples, and Shopping',
          description: 'Discover the city\'s technological prowess, spiritual side, and bustling markets.',
          activities: [
            Activity(time: '11:00 AM', title: 'Visvesvaraya Museum', description: 'An interactive science and technology museum perfect for all ages.', icon: Icons.science_outlined),
            Activity(time: '3:00 PM', title: 'ISKCON Temple Bangalore', description: 'Visit the stunning and spiritual ISKCON temple on Hare Krishna Hill.', icon: Icons.temple_hindu_outlined),
            Activity(time: '6:00 PM', title: 'Shopping on Commercial Street', description: 'Explore one of the city\'s oldest and busiest shopping areas for great deals.', icon: Icons.shopping_bag_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 3: Art & History',
          description: 'Dive into the rich artistic and historical fabric of the city.',
          activities: [
            Activity(time: '11:00 AM', title: 'Karnataka Chitrakala Parishath', description: 'Explore a complex of art galleries showcasing traditional and contemporary Indian art.', icon: Icons.palette_outlined),
            Activity(time: '2:00 PM', title: 'Tipu Sultan\'s Summer Palace', description: 'Visit the elegant summer residence, known for its teak pillars and ornamental frescoes.', icon: Icons.museum_outlined),
            Activity(time: '5:00 PM', title: 'Bull Temple (Nandi Temple)', description: 'See the massive granite monolith of Nandi, one of the oldest temples in Bangalore.', icon: Icons.pets_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 4: Day Trip to Nandi Hills',
          description: 'An early morning trip to witness a breathtaking sunrise above the clouds.',
          activities: [
            Activity(time: '5:00 AM', title: 'Depart for Nandi Hills', description: 'Start early to catch the spectacular sunrise from this ancient hill fortress.', icon: Icons.directions_car_outlined),
            Activity(time: '10:00 AM', title: 'Explore the Hills', description: 'Visit Tipu\'s Drop, ancient temples, and enjoy the pleasant climate.', icon: Icons.landscape_outlined),
            Activity(time: '2:00 PM', title: 'Lunch near Devanahalli', description: 'Enjoy a meal at a local restaurant on your way back to the city.', icon: Icons.restaurant_menu_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 5: Modern Bangalore & Departure',
          description: 'Experience the modern side of the city before you leave.',
          activities: [
            Activity(time: '11:00 AM', title: 'UB City for Luxury Shopping', description: 'Explore the high-end mall for luxury brands and a sophisticated atmosphere.', icon: Icons.shopping_cart_checkout_outlined),
            Activity(time: '1:00 PM', title: 'Farewell Lunch at a Cafe', description: 'Enjoy a final meal in the trendy Church Street or Koramangala area.', icon: Icons.restaurant_outlined),
            Activity(time: '4:00 PM', title: 'Depart for Airport', description: 'Head to the airport for your journey home.', icon: Icons.flight_takeoff_outlined),
          ],
        ),
      ],
    ),
    // --- UPDATED: KOCHI (5 DAYS) ---
    'kochi': Itinerary(
      destination: 'Kochi',
      title: 'Exploring the Queen of the Arabian Sea',
      dayPlans: [
        DayPlan(
          dayTitle: 'Day 1: Fort Kochi Heritage',
          description: 'Immerse yourself in the colonial history and artistic vibe of Fort Kochi.',
          activities: [
            Activity(time: '3:00 PM', title: 'Chinese Fishing Nets', description: 'Witness the iconic and ancient fishing technique at sunset.', icon: Icons.camera_alt_outlined),
            Activity(time: '6:00 PM', title: 'Kathakali Performance', description: 'Experience a traditional and dramatic Keralan dance performance.', icon: Icons.theater_comedy_outlined),
            Activity(time: '8:00 PM', title: 'Dinner at a heritage hotel', description: 'Dine in a restored colonial bungalow in the heart of Fort Kochi.', icon: Icons.restaurant_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 2: Mattancherry & History',
          description: 'Explore the historic Jew Town and the rich past of the region.',
          activities: [
            Activity(time: '10:00 AM', title: 'Mattancherry Palace (Dutch Palace)', description: 'Famous for its stunning murals depicting Hindu temple art and portraits.', icon: Icons.museum_outlined),
            Activity(time: '12:00 PM', title: 'Jew Town & Paradesi Synagogue', description: 'Walk through antique shops and visit the oldest active synagogue in the Commonwealth.', icon: Icons.synagogue_outlined),
            Activity(time: '3:00 PM', title: 'St. Francis Church', description: 'Visit the oldest European church in India, where Vasco da Gama was originally buried.', icon: Icons.church_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 3: Backwater Bliss',
          description: 'A day trip to experience the serene and world-famous Kerala backwaters.',
          activities: [
            Activity(time: '10:00 AM', title: 'Travel to Alleppey (Alappuzha)', description: 'Take a scenic drive to the Venice of the East, the gateway to the backwaters.', icon: Icons.directions_car_outlined),
            Activity(time: '12:00 PM', title: 'Houseboat Day Cruise', description: 'Board a traditional houseboat for a peaceful cruise through tranquil canals.', icon: Icons.directions_boat_outlined),
            Activity(time: '1:00 PM', title: 'Traditional Keralan Lunch', description: 'Enjoy an authentic meal served on a banana leaf right on the houseboat.', icon: Icons.restaurant_menu_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 4: Modern Ernakulam & Shopping',
          description: 'Explore the bustling modern side of the city.',
          activities: [
            Activity(time: '11:00 AM', title: 'Marine Drive Promenade', description: 'Enjoy a walk along the picturesque walkway facing the backwaters.', icon: Icons.stroller_outlined),
            Activity(time: '2:00 PM', title: 'Shopping at Lulu Mall', description: 'Visit one of India\'s largest and most popular shopping malls.', icon: Icons.shopping_cart_outlined),
            Activity(time: '7:00 PM', title: 'Sunset from Rainbow Bridge', description: 'Capture beautiful photos of the sunset over the backwaters from this iconic bridge.', icon: Icons.camera_alt_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 5: Beach Relaxation & Departure',
          description: 'A relaxing final day before your journey home.',
          activities: [
            Activity(time: '10:00 AM', title: 'Visit Cherai Beach', description: 'Known for its calm waves and beautiful scenery where backwaters meet the sea.', icon: Icons.beach_access_outlined),
            Activity(time: '1:00 PM', title: 'Farewell Seafood Lunch', description: 'Enjoy a final, delicious seafood meal at a beachside restaurant.', icon: Icons.set_meal_outlined),
            Activity(time: '4:00 PM', title: 'Depart for Airport', description: 'Head to Cochin International Airport for your journey home.', icon: Icons.flight_takeoff_outlined),
          ],
        ),
      ],
    ),

    // --- UPDATED: CHENNAI (5 DAYS) ---
    'chennai': Itinerary(
      destination: 'Chennai',
      title: 'The Soulful Gateway to South India',
      dayPlans: [
        DayPlan(
          dayTitle: 'Day 1: Temples, Beaches, and History',
          description: 'Explore the cultural and historical landmarks of the city.',
          activities: [
            Activity(time: '10:00 AM', title: 'Kapaleeshwarar Temple', description: 'Admire the vibrant Dravidian architecture of this ancient Shiva temple in Mylapore.', icon: Icons.temple_hindu_outlined),
            Activity(time: '1:00 PM', title: 'South Indian Thali Lunch', description: 'Savor an authentic and elaborate meal at a traditional restaurant.', icon: Icons.restaurant_menu_outlined),
            Activity(time: '4:00 PM', title: 'Marina Beach at Sunset', description: 'Walk along the second-longest urban beach in the world and see the lighthouse.', icon: Icons.beach_access_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 2: Colonial Past and Modern Art',
          description: 'Discover the colonial roots and artistic expressions of Chennai.',
          activities: [
            Activity(time: '11:00 AM', title: 'Fort St. George', description: 'Visit the first English fortress in India, which now houses a museum.', icon: Icons.fort_outlined),
            Activity(time: '3:00 PM', title: 'Government Museum', description: 'Explore one of the oldest museums in India, known for its rich archaeological and numismatic collections.', icon: Icons.museum_outlined),
            Activity(time: '6:00 PM', title: 'Shopping in T. Nagar', description: 'Experience the bustling commercial heart of Chennai, famous for silks and jewelry.', icon: Icons.shopping_cart_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 3: Day Trip to Mahabalipuram',
          description: 'Explore the ancient rock-cut temples and stone carvings of this UNESCO World Heritage site.',
          activities: [
            Activity(time: '10:00 AM', title: 'Shore Temple', description: 'Visit the iconic temple complex overlooking the Bay of Bengal.', icon: Icons.temple_hindu_outlined),
            Activity(time: '12:00 PM', title: 'Pancha Rathas (Five Rathas)', description: 'Marvel at the five monolithic rock temples, each carved from a single stone.', icon: Icons.architecture_outlined),
            Activity(time: '3:00 PM', title: 'Arjuna\'s Penance', description: 'See the massive open-air rock relief depicting scenes from the Mahabharata.', icon: Icons.history_edu_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 4: Culture & Spirituality',
          description: 'Experience the city\'s deep-rooted cultural and spiritual institutions.',
          activities: [
            Activity(time: '11:00 AM', title: 'Kalakshetra Foundation', description: 'Visit the renowned cultural academy dedicated to the preservation of traditional Indian art forms.', icon: Icons.music_note_outlined),
            Activity(time: '3:00 PM', title: 'Theosophical Society', description: 'Walk through the serene and green campus, home to the giant Adyar Banyan Tree.', icon: Icons.nature_people_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 5: Relaxation & Departure',
          description: 'A peaceful morning before your departure.',
          activities: [
            Activity(time: '10:00 AM', title: 'Besant Nagar Beach (Elliots Beach)', description: 'A quieter beach, perfect for a relaxing morning walk and coffee.', icon: Icons.coffee_outlined),
            Activity(time: '1:00 PM', title: 'Farewell Lunch', description: 'Enjoy a final South Indian meal before heading to the airport.', icon: Icons.restaurant_outlined),
          ],
        ),
      ],
    ),

    // --- UPDATED: TRIVANDRUM (5 DAYS) ---
    'trivandrum': Itinerary(
      destination: 'Trivandrum',
      title: 'Capital of God\'s Own Country',
      dayPlans: [
        DayPlan(
          dayTitle: 'Day 1: Temples, Palaces, and Sunset Beach',
          description: 'A day of spiritual discovery, royal history, and coastal beauty.',
          activities: [
            Activity(time: '10:00 AM', title: 'Padmanabhaswamy Temple', description: 'Visit the magnificent temple known for its intricate architecture and immense treasures.', icon: Icons.temple_hindu_outlined),
            Activity(time: '1:00 PM', title: 'Napier Museum & Zoo', description: 'Explore the Indo-Saracenic museum and the well-maintained zoological park.', icon: Icons.museum_outlined),
            Activity(time: '5:00 PM', title: 'Sunset at Kovalam Beach', description: 'Witness a spectacular sunset from the Lighthouse Beach, one of India\'s most famous.', icon: Icons.wb_sunny_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 2: Backwaters and Estuaries',
          description: 'Experience the serene natural beauty at the confluence of rivers and sea.',
          activities: [
            Activity(time: '11:00 AM', title: 'Poovar Island Boat Tour', description: 'Take a scenic boat ride through mangrove forests where the river meets the sea.', icon: Icons.directions_boat_outlined),
            Activity(time: '3:00 PM', title: 'Veli Tourist Village', description: 'Enjoy the floating bridge and beautiful gardens at this unique picnic spot.', icon: Icons.park_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 3: History & Art',
          description: 'Explore the royal art collections and historic palaces.',
          activities: [
            Activity(time: '11:00 AM', title: 'Sree Chitra Art Gallery', description: 'View a rich collection of paintings by Raja Ravi Varma and other famous artists.', icon: Icons.palette_outlined),
            Activity(time: '2:00 PM', title: 'Kuthiramalika Palace Museum', description: 'Discover the palace of the Travancore royal family, known for its traditional Kerala architecture.', icon: Icons.castle_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 4: Day Trip to Kanyakumari',
          description: 'Journey to the southernmost tip of India to witness the confluence of three seas.',
          activities: [
            Activity(time: '8:00 AM', title: 'Drive to Kanyakumari', description: 'A scenic 2-3 hour drive to the land\'s end.', icon: Icons.directions_car_outlined),
            Activity(time: '11:00 AM', title: 'Vivekananda Rock Memorial', description: 'Take a ferry to the rock memorial where the spiritual leader meditated.', icon: Icons.sailing_outlined),
            Activity(time: '2:00 PM', title: 'Thiruvalluvar Statue', description: 'View the towering stone statue of the renowned Tamil poet and philosopher.', icon: Icons.architecture_outlined),
          ],
        ),
        DayPlan(
          dayTitle: 'Day 5: Hills & Departure',
          description: 'A refreshing trip to a nearby hill station before you leave.',
          activities: [
            Activity(time: '9:00 AM', title: 'Trip to Ponmudi Hills', description: 'Enjoy the winding roads and cool climate of this beautiful hill station.', icon: Icons.landscape_outlined),
            Activity(time: '1:00 PM', title: 'Lunch with a View', description: 'Dine at a restaurant in Ponmudi offering panoramic views.', icon: Icons.restaurant_outlined),
          ],
        ),
      ],
    ),
  };


  /// Fetches the pre-written itinerary for a given destination and duration.
  static Itinerary? getItinerary(String destination, int durationInDays) {
    // We convert the destination to lowercase to make the search case-insensitive.
    final key = destination.toLowerCase().trim();
    if (_itineraries.containsKey(key)) {
      final fullItinerary = _itineraries[key]!;
      // Return a new Itinerary object with the plan sliced to the requested duration.
      return Itinerary(
        destination: fullItinerary.destination,
        title: fullItinerary.title,
        dayPlans: fullItinerary.dayPlans.take(durationInDays).toList(),
      );
    }
    return null; // Return null if no itinerary is found.
  }
}