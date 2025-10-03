// Mock database for testing when MongoDB is not available
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

class MockDatabase {
  constructor() {
    this.data = { ...mockData };
  }

  // Mock MongoDB-like methods
  find(collection, query = {}) {
    const data = this.data[collection] || [];
    return Promise.resolve(data);
  }

  findById(collection, id) {
    const data = this.data[collection] || [];
    const item = data.find(item => item._id === id);
    return Promise.resolve(item);
  }

  findOne(collection, query = {}) {
    const data = this.data[collection] || [];
    const item = data.find(item => {
      return Object.keys(query).every(key => item[key] === query[key]);
    });
    return Promise.resolve(item);
  }

  create(collection, data) {
    if (!this.data[collection]) {
      this.data[collection] = [];
    }
    const newItem = { ...data, _id: Date.now().toString() };
    this.data[collection].push(newItem);
    return Promise.resolve(newItem);
  }

  update(collection, id, data) {
    if (!this.data[collection]) {
      return Promise.resolve(null);
    }
    const index = this.data[collection].findIndex(item => item._id === id);
    if (index === -1) {
      return Promise.resolve(null);
    }
    this.data[collection][index] = { ...this.data[collection][index], ...data };
    return Promise.resolve(this.data[collection][index]);
  }

  delete(collection, id) {
    if (!this.data[collection]) {
      return Promise.resolve(false);
    }
    const index = this.data[collection].findIndex(item => item._id === id);
    if (index === -1) {
      return Promise.resolve(false);
    }
    this.data[collection].splice(index, 1);
    return Promise.resolve(true);
  }

  count(collection, query = {}) {
    const data = this.data[collection] || [];
    return Promise.resolve(data.length);
  }
}

module.exports = new MockDatabase();
