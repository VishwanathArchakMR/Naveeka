// Simple server for testing frontend-backend connection
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:8080', 'http://127.0.0.1:3000', 'http://127.0.0.1:8080'],
  credentials: true
}));
app.use(express.json());

// Mock data
const mockData = {
  activities: [
    {
      _id: '1',
      name: 'Old Goa Heritage Walk',
      description: 'A guided walking tour through Old Goa\'s UNESCO heritage sites and hidden lanes.',
      type: 'tour',
      categories: ['culture', 'history'],
      tags: ['walking', 'architecture', 'heritage', 'photography'],
      city: 'Goa',
      country: 'India',
      location: {
        type: 'Point',
        coordinates: [73.9096, 15.5007]
      },
      durationMin: 120,
      capacity: 20,
      language: ['en'],
      price: { amount: 799, currency: 'INR' },
      features: ['guide', 'small_group'],
      reviews: { averageRating: 4.6, totalReviews: 128 },
      photos: [
        'https://example-cdn/img/goa_heritage_1.jpg',
        'https://example-cdn/img/goa_heritage_2.jpg'
      ],
      popularity: 92,
      viewCount: 2180,
      isActive: true
    },
    {
      _id: '2',
      name: 'Mandovi Sunset Cruise',
      description: 'Evening cruise on the Mandovi river with live music and local snacks.',
      type: 'experience',
      categories: ['leisure'],
      tags: ['boat', 'sunset', 'music'],
      city: 'Goa',
      country: 'India',
      location: {
        type: 'Point',
        coordinates: [73.8278, 15.4989]
      },
      durationMin: 90,
      capacity: 80,
      language: ['en', 'hi'],
      price: { amount: 1299, currency: 'INR' },
      features: ['live_music', 'snacks'],
      reviews: { averageRating: 4.3, totalReviews: 412 },
      photos: [
        'https://example-cdn/img/mandovi_1.jpg',
        'https://example-cdn/img/mandovi_2.jpg'
      ],
      popularity: 88,
      viewCount: 5340,
      isActive: true
    },
    {
      _id: '3',
      name: 'Fontainhas Art District Photo Walk',
      description: 'Explore the vibrant lanes of Fontainhas and capture colorful Portuguese-era homes.',
      type: 'tour',
      categories: ['culture', 'photography'],
      tags: ['walking', 'art', 'colors'],
      city: 'Goa',
      country: 'India',
      location: {
        type: 'Point',
        coordinates: [73.8295, 15.4981]
      },
      durationMin: 150,
      capacity: 15,
      language: ['en'],
      price: { amount: 999, currency: 'INR' },
      features: ['guide', 'photo_tips'],
      reviews: { averageRating: 4.8, totalReviews: 89 },
      photos: [
        'https://example-cdn/img/fontainhas_1.jpg',
        'https://example-cdn/img/fontainhas_2.jpg'
      ],
      popularity: 75,
      viewCount: 1840,
      isActive: true
    }
  ],
  places: [
    {
      _id: '1',
      name: 'Sri Krishna Temple',
      category: 'Temples',
      emotion: 'Spiritual',
      description: 'Ancient temple dedicated to Lord Krishna...',
      history: 'Founded in the 13th century by Saint Madhvacharya...',
      location: { type: 'Point', coordinates: [74.7421, 13.3409] },
      coverImage: 'https://images.pexels.com/photos/2780762/pexels-photo-2780762.jpeg',
      gallery: ['https://images.pexels.com/photos/2780762/pexels-photo-2780762.jpeg'],
      timings: '5:30 AM - 1:00 PM, 3:00 PM - 9:00 PM',
      phone: '+91 8252 253 001',
      regionPath: 'India/Karnataka/Udupi/Udupi Taluk/Udupi City',
      price: 0,
      entryFee: 0,
      tags: ['ancient', 'madhvacharya', 'krishna', 'darshan'],
      amenities: ['parking', 'prasadam', 'restrooms', 'wheelchair access'],
      bestTimeToVisit: 'Year round, special festivals during Janmashtami',
      parkingAvailable: true,
      wheelchairAccessible: true,
      petFriendly: false
    },
    {
      _id: '2',
      name: 'Malpe Beach',
      category: 'Peaceful',
      emotion: 'Peaceful',
      description: 'Pristine beach with golden sands...',
      history: 'Malpe has been a major port town since ancient times...',
      location: { type: 'Point', coordinates: [74.7052, 13.3508] },
      coverImage: 'https://images.pexels.com/photos/1032650/pexels-photo-1032650.jpeg',
      gallery: ['https://images.pexels.com/photos/1032650/pexels-photo-1032650.jpeg'],
      timings: 'Open 24 hours',
      regionPath: 'India/Karnataka/Udupi/Udupi Taluk/Udupi City/Malpe',
      price: 0,
      entryFee: 0,
      tags: ['beach', 'sunset', 'boats', 'swimming'],
      amenities: ['parking', 'restaurants', 'water sports', 'boat rides'],
      bestTimeToVisit: 'October to March for pleasant weather',
      parkingAvailable: true,
      wheelchairAccessible: false,
      petFriendly: true
    }
  ],
  regions: [
    {
      _id: '1',
      name: 'India',
      type: 'country',
      code: 'IN',
      description: 'Republic of India - diverse landscapes from Himalayas to coastal plains',
      center: { type: 'Point', coordinates: [78.96288, 20.593684] }
    },
    {
      _id: '2',
      name: 'Karnataka',
      type: 'state',
      code: 'KA',
      parentId: '1',
      description: 'Land of heritage, technology, and diverse landscapes',
      center: { type: 'Point', coordinates: [75.7139, 15.3173] }
    }
  ]
};

// Health check
app.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'OK',
    message: 'Naveeka Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Activities API
app.get('/api/activities', (req, res) => {
  const { category, city, limit = 10, page = 1 } = req.query;
  
  let activities = mockData.activities;
  
  // Apply filters
  if (category) {
    activities = activities.filter(activity => 
      activity.categories.includes(category) || activity.tags.includes(category)
    );
  }
  
  if (city) {
    activities = activities.filter(activity => 
      activity.city.toLowerCase().includes(city.toLowerCase())
    );
  }
  
  // Pagination
  const startIndex = (page - 1) * limit;
  const endIndex = startIndex + parseInt(limit);
  const paginatedActivities = activities.slice(startIndex, endIndex);
  
  res.json({
    success: true,
    data: {
      activities: paginatedActivities,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: activities.length,
        pages: Math.ceil(activities.length / limit)
      }
    }
  });
});

app.get('/api/activities/:id', (req, res) => {
  const { id } = req.params;
  const activity = mockData.activities.find(a => a._id === id);
  
  if (!activity) {
    return res.status(404).json({
      success: false,
      message: 'Activity not found'
    });
  }
  
  res.json({
    success: true,
    data: { activity }
  });
});

// Places API
app.get('/api/places', (req, res) => {
  const { category, emotion, search, limit = 10, page = 1 } = req.query;
  
  let places = mockData.places;
  
  // Apply filters
  if (category) {
    places = places.filter(place => place.category === category);
  }
  
  if (emotion) {
    places = places.filter(place => place.emotion === emotion);
  }
  
  if (search) {
    places = places.filter(place => 
      place.name.toLowerCase().includes(search.toLowerCase()) ||
      place.description.toLowerCase().includes(search.toLowerCase())
    );
  }
  
  // Pagination
  const startIndex = (page - 1) * limit;
  const endIndex = startIndex + parseInt(limit);
  const paginatedPlaces = places.slice(startIndex, endIndex);
  
  res.json({
    success: true,
    data: {
      places: paginatedPlaces,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: places.length,
        pages: Math.ceil(places.length / limit)
      }
    }
  });
});

app.get('/api/places/:id', (req, res) => {
  const { id } = req.params;
  const place = mockData.places.find(p => p._id === id);
  
  if (!place) {
    return res.status(404).json({
      success: false,
      message: 'Place not found'
    });
  }
  
  res.json({
    success: true,
    data: { place }
  });
});

// Regions API
app.get('/api/regions', (req, res) => {
  const { type } = req.query;
  
  let regions = mockData.regions;
  
  if (type) {
    regions = regions.filter(region => region.type === type);
  }
  
  res.json({
    success: true,
    data: { regions }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Naveeka Backend Server running on port ${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/health`);
  console.log(`🎯 Activities API: http://localhost:${PORT}/api/activities`);
  console.log(`🏛️ Places API: http://localhost:${PORT}/api/places`);
  console.log(`🗺️ Regions API: http://localhost:${PORT}/api/regions`);
});

module.exports = app;
