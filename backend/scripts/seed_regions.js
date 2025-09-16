// backend/scripts/seed_regions.js
require('dotenv').config();
const mongoose = require('mongoose');
const Region = require('../models/region');
const Place = require('../models/place');
const User = require('../models/user');
const connectDB = require('../config/database');

function getBoundsApprox(centerLng, centerLat, spanLng = 2, spanLat = 2) {
  const halfLng = Math.max(0.01, spanLng / 2);
  const halfLat = Math.max(0.01, spanLat / 2);
  return [centerLng - halfLng, centerLat - halfLat, centerLng + halfLng, centerLat + halfLat];
}
function point(lng, lat) {
  return { type: 'Point', coordinates: [lng, lat] };
}

const atlasTrailData = {
  users: [
    { name: 'Admin User', email: 'admin@atlastrail.com', phone: '9876543210', password: 'admin123', role: 'admin', preferences: ['Spiritual', 'Heritage', 'Nature'], isVerified: true, isActive: true },
    { name: 'Travel Partner', email: 'partner@atlastrail.com', phone: '9876543211', password: 'partner123', role: 'partner', preferences: ['Adventure', 'Nature', 'Peaceful'], isVerified: true, isActive: true }
  ],
  regions: [
    { name: 'India', type: 'country', code: 'IN', description: 'Republic of India - diverse landscapes from Himalayas to coastal plains', center: point(78.96288, 20.593684), bbox: [68.17665, 6.554607, 97.40256, 35.674545], metadata: { population: 1380000000, area: 3287263, established: new Date('1947-08-15') } },
    { name: 'Karnataka', type: 'state', code: 'KA', parentName: 'India', description: 'Land of heritage, technology, and diverse landscapes', center: point(75.7139, 15.3173), bbox: [74.092, 11.593, 78.586, 18.476], metadata: { population: 64113000, area: 191791 } },
    { name: 'Udupi', type: 'district', parentName: 'Karnataka', description: 'Temple town famous for Krishna temple and coastal cuisine', center: point(74.75, 13.34), bbox: getBoundsApprox(74.75, 13.34, 0.8, 0.6), metadata: { population: 1177361, area: 3575 } },
    { name: 'Chikmagalur', type: 'district', parentName: 'Karnataka', description: 'Coffee capital of India with hill stations and trekking trails', center: point(75.78, 13.32), bbox: getBoundsApprox(75.78, 13.32, 1.0, 1.0), metadata: { population: 1137961, area: 7201 } },
    { name: 'Mysore', type: 'district', parentName: 'Karnataka', description: 'City of palaces with rich cultural heritage', center: point(76.64, 12.30), bbox: getBoundsApprox(76.64, 12.30, 1.0, 1.0), metadata: { population: 3001127, area: 6854 } },
    { name: 'Udupi Taluk', type: 'taluk', parentName: 'Udupi', description: 'Central taluk with the famous Krishna temple', center: point(74.75, 13.34), bbox: getBoundsApprox(74.75, 13.34, 0.4, 0.3) },
    { name: 'Karkala', type: 'taluk', parentName: 'Udupi', description: 'Hill station with ancient Jain monuments', center: point(74.99, 13.22), bbox: getBoundsApprox(74.99, 13.22, 0.4, 0.3) },
    { name: 'Chikmagalur Taluk', type: 'taluk', parentName: 'Chikmagalur', description: 'Coffee plantation region with hill stations', center: point(75.78, 13.31), bbox: getBoundsApprox(75.78, 13.31, 0.4, 0.3) },
    { name: 'Mudigere', type: 'taluk', parentName: 'Chikmagalur', description: 'Western Ghats region with biodiversity', center: point(75.63, 13.13), bbox: getBoundsApprox(75.63, 13.13, 0.4, 0.3) },
    { name: 'Mysore Taluk', type: 'taluk', parentName: 'Mysore', description: 'Royal city with palaces and gardens', center: point(76.65, 12.31), bbox: getBoundsApprox(76.65, 12.31, 0.4, 0.3) },
    { name: 'Nanjangud', type: 'taluk', parentName: 'Mysore', description: 'Temple town on banks of river Kapila', center: point(76.68, 12.12), bbox: getBoundsApprox(76.68, 12.12, 0.4, 0.3) },
    { name: 'Udupi City', type: 'town', parentName: 'Udupi Taluk', description: 'Temple city and educational hub', center: point(74.75, 13.34), bbox: getBoundsApprox(74.75, 13.34, 0.2, 0.2) },
    { name: 'Manipal', type: 'town', parentName: 'Udupi Taluk', description: 'University town with medical and engineering colleges', center: point(74.79, 13.35), bbox: getBoundsApprox(74.79, 13.35, 0.2, 0.2) },
    { name: 'Karkala Town', type: 'town', parentName: 'Karkala', description: 'Historic town with Jain heritage', center: point(74.99, 13.22), bbox: getBoundsApprox(74.99, 13.22, 0.2, 0.2) },
    { name: 'Chikmagalur Town', type: 'town', parentName: 'Chikmagalur Taluk', description: 'Coffee town with colonial architecture', center: point(75.77, 13.32), bbox: getBoundsApprox(75.77, 13.32, 0.2, 0.2) },
    { name: 'Mudigere Town', type: 'town', parentName: 'Mudigere', description: 'Gateway to Western Ghats', center: point(75.63, 13.13), bbox: getBoundsApprox(75.63, 13.13, 0.2, 0.2) },
    { name: 'Mysore City', type: 'town', parentName: 'Mysore Taluk', description: 'Cultural capital of Karnataka', center: point(76.65, 12.31), bbox: getBoundsApprox(76.65, 12.31, 0.2, 0.2) },
    { name: 'Nanjangud Town', type: 'town', parentName: 'Nanjangud', description: 'Dakshina Kashi - southern Varanasi', center: point(76.69, 12.12), bbox: getBoundsApprox(76.69, 12.12, 0.2, 0.2) },
    { name: 'Malpe', type: 'village', parentName: 'Udupi City', description: 'Famous beach village with St. Marys Island nearby', center: point(74.7052, 13.3508), bbox: getBoundsApprox(74.7052, 13.3508, 0.08, 0.06) },
    { name: 'Kaup', type: 'village', parentName: 'Udupi City', description: 'Lighthouse beach village', center: point(74.744, 13.212), bbox: getBoundsApprox(74.744, 13.212, 0.08, 0.06) },
    { name: 'Hebri', type: 'village', parentName: 'Karkala Town', description: 'Village in Western Ghats foothills', center: point(74.988, 13.327), bbox: getBoundsApprox(74.988, 13.327, 0.08, 0.06) },
    { name: 'Ajekar', type: 'village', parentName: 'Karkala Town', description: 'Traditional village with ancient temples', center: point(75.02, 13.22), bbox: getBoundsApprox(75.02, 13.22, 0.08, 0.06) },
    { name: 'Kemmanagundi', type: 'village', parentName: 'Chikmagalur Town', description: 'Hill station with gardens and waterfalls', center: point(75.78, 13.53), bbox: getBoundsApprox(75.78, 13.53, 0.08, 0.06) },
    { name: 'Balehonnur', type: 'village', parentName: 'Chikmagalur Town', description: 'Coffee plantation village', center: point(75.52, 13.33), bbox: getBoundsApprox(75.52, 13.33, 0.08, 0.06) },
    { name: 'Kudremukh', type: 'village', parentName: 'Mudigere Town', description: 'Iron ore mining region with national park', center: point(75.25, 13.13), bbox: getBoundsApprox(75.25, 13.13, 0.08, 0.06) },
    { name: 'Kalasa', type: 'village', parentName: 'Mudigere Town', description: 'Temple village in Western Ghats', center: point(75.35, 13.23), bbox: getBoundsApprox(75.35, 13.23, 0.08, 0.06) },
    { name: 'Srirangapatna', type: 'village', parentName: 'Mysore City', description: 'Island fortress of Tipu Sultan', center: point(76.68, 12.42), bbox: getBoundsApprox(76.68, 12.42, 0.08, 0.06) },
    { name: 'Gundlupet', type: 'village', parentName: 'Nanjangud Town', description: 'Gateway to Bandipur National Park', center: point(76.69, 11.81), bbox: getBoundsApprox(76.69, 11.81, 0.08, 0.06) }
  ],
  places: [
    {
      name: 'Sri Krishna Temple',
      category: 'Temples',
      emotion: 'Spiritual',
      description: 'Ancient temple dedicated to Lord Krishna...',
      history: 'Founded in the 13th century by Saint Madhvacharya...',
      location: { type: 'Point', coordinates: [74.7421, 13.3409] }, // GeoJSON [lng,lat]
      coverImage: 'https://images.pexels.com/photos/2780762/pexels-photo-2780762.jpeg',
      gallery: ['https://images.pexels.com/photos/2780762/pexels-photo-2780762.jpeg','https://images.pexels.com/photos/4666748/pexels-photo-4666748.jpeg'],
      timings: '5:30 AM - 1:00 PM, 3:00 PM - 9:00 PM',
      phone: '+91 8252 253 001',
      regionPath: 'India/Karnataka/Udupi/Udupi Taluk/Udupi City',
      villageRef: 'Udupi City',
      price: 0,
      entryFee: 0,
      tags: ['ancient', 'madhvacharya', 'krishna', 'darshan'],
      amenities: ['parking', 'prasadam', 'restrooms', 'wheelchair access'],
      bestTimeToVisit: 'Year round, special festivals during Janmashtami',
      parkingAvailable: true,
      wheelchairAccessible: true,
      petFriendly: false,
      comments: [{ userName: 'Devotee Raj', text: 'Peaceful and divine experience. The prasadam is amazing!', rating: 5, images: [] }]
    },
    {
      name: 'Malpe Beach',
      category: 'Peaceful',
      emotion: 'Peaceful',
      description: 'Pristine beach with golden sands...',
      history: 'Malpe has been a major port town since ancient times...',
      location: { type: 'Point', coordinates: [74.7052, 13.3508] },
      coverImage: 'https://images.pexels.com/photos/1032650/pexels-photo-1032650.jpeg',
      gallery: ['https://images.pexels.com/photos/1032650/pexels-photo-1032650.jpeg','https://images.pexels.com/photos/457882/pexels-photo-457882.jpeg'],
      timings: 'Open 24 hours',
      regionPath: 'India/Karnataka/Udupi/Udupi Taluk/Udupi City/Malpe',
      villageRef: 'Malpe',
      price: 0,
      entryFee: 0,
      tags: ['beach', 'sunset', 'boats', 'swimming'],
      amenities: ['parking', 'restaurants', 'water sports', 'boat rides'],
      bestTimeToVisit: 'October to March for pleasant weather',
      parkingAvailable: true,
      wheelchairAccessible: false,
      petFriendly: true,
      comments: [{ userName: 'Beach Lover', text: 'Beautiful sunset views and clean beach. Perfect for families!', rating: 5, images: [] }]
    },
    {
      name: 'St. Marys Island',
      category: 'Adventure',
      emotion: 'Adventure',
      description: 'Unique hexagonal basaltic rock formations...',
      history: 'Discovered by Vasco da Gama in 1498...',
      location: { type: 'Point', coordinates: [74.6917, 13.3625] },
      coverImage: 'https://images.pexels.com/photos/1001682/pexels-photo-1001682.jpeg',
      gallery: ['https://images.pexels.com/photos/1001682/pexels-photo-1001682.jpeg','https://images.pexels.com/photos/2662116/pexels-photo-2662116.jpeg'],
      timings: '9:00 AM - 5:00 PM (depends on boat availability)',
      regionPath: 'India/Karnataka/Udupi/Udupi Taluk/Udupi City/Malpe',
      villageRef: 'Malpe',
      price: 0,
      entryFee: 200,
      tags: ['island', 'geology', 'boat ride', 'unique formations'],
      amenities: ['boat transport', 'guided tours', 'photography spots'],
      bestTimeToVisit: 'October to March, avoid monsoons',
      parkingAvailable: false,
      wheelchairAccessible: false,
      petFriendly: false,
      comments: []
    },
    {
      name: 'Mullayanagiri Peak',
      category: 'Adventure',
      emotion: 'Adventure',
      description: 'Highest peak in Karnataka...',
      history: 'Named after Mulappa Swamy...',
      location: { type: 'Point', coordinates: [75.7249, 13.3931] },
      coverImage: 'https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg',
      gallery: ['https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg','https://images.pexels.com/photos/1624496/pexels-photo-1624496.jpeg'],
      timings: '6:00 AM - 6:00 PM',
      regionPath: 'India/Karnataka/Chikmagalur/Chikmagalur Taluk/Chikmagalur Town/Kemmanagundi',
      villageRef: 'Kemmanagundi',
      price: 0,
      entryFee: 0,
      tags: ['highest peak', 'trekking', 'sunrise', 'mountains'],
      amenities: ['trekking trails', 'viewpoints', 'camping areas'],
      bestTimeToVisit: 'September to February for clear views',
      parkingAvailable: true,
      wheelchairAccessible: false,
      petFriendly: true,
      comments: [{ userName: 'Trekker Pro', text: 'Amazing sunrise views! The trek is moderately challenging but worth it.', rating: 5, images: [] }]
    },
    {
      name: 'Coffee Plantations',
      category: 'Nature',
      emotion: 'Peaceful',
      description: 'Lush green coffee estates...',
      history: 'Coffee cultivation began here in the 17th century...',
      location: { type: 'Point', coordinates: [75.7720, 13.3161] },
      coverImage: 'https://images.pexels.com/photos/442406/pexels-photo-442406.jpeg',
      gallery: ['https://images.pexels.com/photos/442406/pexels-photo-442406.jpeg','https://images.pexels.com/photos/302899/pexels-photo-302899.jpeg'],
      timings: '8:00 AM - 5:00 PM',
      regionPath: 'India/Karnataka/Chikmagalur/Chikmagalur Taluk/Chikmagalur Town/Balehonnur',
      villageRef: 'Balehonnur',
      price: 500,
      entryFee: 300,
      tags: ['coffee', 'plantation', 'tours', 'nature'],
      amenities: ['guided tours', 'coffee tasting', 'gift shop', 'homestays'],
      bestTimeToVisit: 'October to March for pleasant weather',
      parkingAvailable: true,
      wheelchairAccessible: true,
      petFriendly: true,
      comments: []
    },
    {
      name: 'Mysore Palace',
      category: 'Heritage',
      emotion: 'Heritage',
      description: 'Magnificent royal palace...',
      history: 'Former residence of the Wodeyar dynasty...',
      location: { type: 'Point', coordinates: [76.6551, 12.3052] },
      coverImage: 'https://images.pexels.com/photos/3573382/pexels-photo-3573382.jpeg',
      gallery: ['https://images.pexels.com/photos/3573382/pexels-photo-3573382.jpeg','https://images.pexels.com/photos/1007657/pexels-photo-1007657.jpeg'],
      timings: '10:00 AM - 5:30 PM',
      phone: '+91 821 242 3693',
      regionPath: 'India/Karnataka/Mysore/Mysore Taluk/Mysore City',
      villageRef: 'Mysore City',
      price: 0,
      entryFee: 70,
      tags: ['palace', 'royal', 'architecture', 'heritage'],
      amenities: ['audio guide', 'museum', 'light show', 'parking'],
      bestTimeToVisit: 'Year round, special during Dussehra festival',
      parkingAvailable: true,
      wheelchairAccessible: true,
      petFriendly: false,
      comments: [{ userName: 'History Buff', text: 'Absolutely stunning architecture! The audio guide is very informative.', rating: 5, images: [] }]
    },
    {
      name: 'Chamundeshwari Temple',
      category: 'Temples',
      emotion: 'Spiritual',
      description: 'Ancient temple atop Chamundi Hills...',
      history: 'Dating back to the 12th century...',
      location: { type: 'Point', coordinates: [76.6421, 12.2719] },
      coverImage: 'https://images.pexels.com/photos/2870167/pexels-photo-2870167.jpeg',
      gallery: ['https://images.pexels.com/photos/2870167/pexels-photo-2870167.jpeg','https://images.pexels.com/photos/3585047/pexels-photo-3585047.jpeg'],
      timings: '5:00 AM - 2:00 PM, 3:30 PM - 9:00 PM',
      phone: '+91 821 248 0316',
      regionPath: 'India/Karnataka/Mysore/Mysore Taluk/Mysore City',
      villageRef: 'Mysore City',
      price: 0,
      entryFee: 0,
      tags: ['temple', 'goddess', 'hills', 'views'],
      amenities: ['parking', 'prasadam', 'viewpoint', 'steps'],
      bestTimeToVisit: 'Year round, early morning for best views',
      parkingAvailable: true,
      wheelchairAccessible: false,
      petFriendly: false,
      comments: []
    },
    {
      name: 'Brindavan Gardens',
      category: 'Nature',
      emotion: 'Peaceful',
      description: 'Beautifully landscaped gardens...',
      history: 'Built in 1927 below the Krishnarajasagara Dam...',
      location: { type: 'Point', coordinates: [76.5750, 12.4244] },
      coverImage: 'https://images.pexels.com/photos/1034584/pexels-photo-1034584.jpeg',
      gallery: ['https://images.pexels.com/photos/1034584/pexels-photo-1034584.jpeg','https://images.pexels.com/photos/1153976/pexels-photo-1153976.jpeg'],
      timings: '6:30 AM - 8:00 PM',
      regionPath: 'India/Karnataka/Mysore/Nanjangud/Nanjangud Town',
      villageRef: 'Nanjangud Town',
      price: 0,
      entryFee: 25,
      tags: ['gardens', 'fountains', 'boating', 'family'],
      amenities: ['boating', 'fountains', 'restaurants', 'parking'],
      bestTimeToVisit: 'Evening for fountain show, avoid summer afternoons',
      parkingAvailable: true,
      wheelchairAccessible: true,
      petFriendly: true,
      comments: [{ userName: 'Family Visitor', text: 'Beautiful gardens and amazing fountain show in the evening!', rating: 4, images: [] }]
    }
  ]
};

async function clearAll() {
  console.log('🧹 Clearing existing data...');
  await Region.deleteMany({});
  await Place.deleteMany({});
  await User.deleteMany({});
  console.log('✅ All data cleared');
}

async function seedUsers() {
  console.log('\n👥 Creating sample users...');
  const createdUsers = {};
  for (const userData of atlasTrailData.users) {
    try {
      const user = await User.findOneAndUpdate({ email: userData.email }, { $setOnInsert: userData }, { upsert: true, new: true, runValidators: true });
      createdUsers[user.role] = user._id;
      console.log(`   ✅ ${user.name} (${user.role})`);
    } catch (error) {
      console.log(`   ❌ Failed to create user ${userData.name}: ${error.message}`);
    }
  }
  return createdUsers;
}

async function seedRegions() {
  console.log('\n🗺️ Creating hierarchical regions...');
  const createdRegions = {};
  const regionsByType = { country: [], state: [], district: [], taluk: [], town: [], village: [] };
  atlasTrailData.regions.forEach(r => regionsByType[r.type].push(r));
  for (const type of ['country', 'state', 'district', 'taluk', 'town', 'village']) {
    console.log(`\n📍 Creating ${type}s...`);
    for (const regionData of regionsByType[type]) {
      try {
        const parentId = regionData.parentName ? createdRegions[regionData.parentName] : null;
        if (regionData.parentName && !parentId) {
          console.log(`   ❌ Parent not found for ${regionData.name}`);
          continue;
        }
        const { parentName, ...cleanData } = regionData;
        const region = await Region.create({ ...cleanData, parentId });
        createdRegions[region.name] = region._id;
        console.log(`   ✅ ${region.name} (${region.type})${parentName ? ` → ${parentName}` : ''}`);
      } catch (error) {
        console.log(`   ❌ Failed to create ${regionData.name}: ${error.message}`);
      }
    }
  }
  return createdRegions;
}

async function seedPlaces(createdRegions, createdUsers) {
  console.log('\n🏛️ Creating places...');
  const createdPlaces = [];
  for (const placeData of atlasTrailData.places) {
    try {
      const villageId = createdRegions[placeData.villageRef];
      if (!villageId) {
        console.log(`   ❌ Village not found for ${placeData.name}: ${placeData.villageRef}`);
        continue;
      }
      const breadcrumb = await Region.getBreadcrumb(villageId);
      const regionRef = {};
      breadcrumb.forEach(r => { regionRef[r.type] = r._id; });

      const { villageRef, comments, ...cleanPlaceData } = placeData;
      const place = await Place.create({
        ...cleanPlaceData,
        regionRef,
        createdBy: createdUsers.partner || createdUsers.admin,
        isApproved: true,
        approvedAt: new Date(),
        approvedBy: createdUsers.admin,
        comments: comments ? comments.map(c => ({ ...c, userId: createdUsers.admin, createdAt: new Date() })) : []
      });
      createdPlaces.push(place);
      console.log(`   ✅ ${place.name} (${place.category}) in ${placeData.villageRef}`);
    } catch (error) {
      console.log(`   ❌ Failed to create place ${placeData.name}: ${error.message}`);
    }
  }
  return createdPlaces;
}

async function displaySummary(createdRegions, createdPlaces) {
  console.log('\n📊 AtlasTrail Seeding Summary:');
  console.log(`   👥 Users: ${atlasTrailData.users.length}`);
  console.log(`   🗺️ Regions: ${Object.keys(createdRegions).length}`);
  console.log(`   🏛️ Places: ${createdPlaces.length}`);
  console.log(`   📈 Total Records: ${atlasTrailData.users.length + Object.keys(createdRegions).length + createdPlaces.length}`);
  console.log('\n🧪 Testing queries...');
  try {
    const karnataka = await Region.findOne({ name: 'Karnataka' });
    if (karnataka) {
      const districts = await Region.getChildren(karnataka._id, 'district');
      console.log(`   🏘️ Karnataka districts: ${districts.map(d => d.name).join(', ')}`);
      const karnatakaPlaces = await Place.find({ 'regionRef.state': karnataka._id, isActive: true, isApproved: true }).select('name category');
      console.log(`   🏛️ Places in Karnataka: ${karnatakaPlaces.length} places`);
    }
    const malpe = await Region.findOne({ name: 'Malpe' });
    if (malpe) {
      const breadcrumb = await Region.getBreadcrumb(malpe._id);
      console.log(`   🧭 Malpe breadcrumb: ${breadcrumb.map(r => r.name).join(' → ')}`);
    }
    const krishnaTemple = await Place.findOne({ name: 'Sri Krishna Temple' }).populate('regionRef.village', 'name');
    if (krishnaTemple && krishnaTemple.regionRef?.village) {
      console.log(`   🏛️ Krishna Temple location: ${krishnaTemple.regionRef.village.name}`);
    }
  } catch (error) {
    console.log(`   ❌ Test query failed: ${error.message}`);
  }
}

async function main() {
  try {
    console.log('🚀 AtlasTrail Complete Data Seeding Started...');
    console.log('\n🔌 Connecting to database...');
    await connectDB();
    console.log('✅ Database connected');

    const shouldClear = process.argv.includes('--clear');
    if (shouldClear) {
      await (async () => {
        console.log('🧹 Clearing existing data...');
        await Region.deleteMany({});
        await Place.deleteMany({});
        await User.deleteMany({});
        console.log('✅ All data cleared');
      })();
    }

    const createdUsers = await seedUsers();
    const createdRegions = await seedRegions();
    const createdPlaces = await seedPlaces(createdRegions, createdUsers);
    await displaySummary(createdRegions, createdPlaces);

    console.log('\n🎉 AtlasTrail seeding complete!');
    console.log('\n💡 Try these API calls:');
    console.log('   GET /api/regions?type=country');
    console.log('   GET /api/regions/root/children');
    console.log('   GET /api/regions/search?q=Udupi');
    console.log('   GET /api/places?regionId={karnataka-id}');
    console.log('   GET /api/places?category=Temples');
    console.log('   GET /api/places?emotion=Spiritual');
    console.log('   POST /api/auth/login (admin@atlastrail.com / admin123)');
  } catch (error) {
    console.error('💥 Seeding failed:', error);
    process.exit(1);
  } finally {
    await mongoose.connection.close();
    console.log('⚠️ MongoDB disconnected');
    console.log('\n🔌 Database connection closed');
    process.exit(0);
  }
}

if (require.main === module) {
  main();
}

module.exports = { atlasTrailData, seedUsers, seedRegions, seedPlaces };
