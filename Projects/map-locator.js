document.addEventListener('DOMContentLoaded', () => {
  const mapContainer = document.getElementById('map-container');
  const locateBtn = document.getElementById('locate-btn');
  const locationInput = document.getElementById('location-input');
  const locationResults = document.getElementById('location-results');

  // Initialize map variable and centers
  let map;
  const defaultCenter = { lat: 39.8283, lng: -98.5795 }; // Center of the US

  // Mock recycling centers data
  const recyclingCenters = [
    { name: 'Downtown Recycling Center', lat: 40.712776, lng: -74.005974, materials: ['Paper', 'Glass', 'Plastic'] },
    { name: 'Green Park Drop-off', lat: 34.052235, lng: -118.243683, materials: ['Metal', 'Electronics'] },
    { name: 'Community Recycle Hub', lat: 41.878113, lng: -87.629799, materials: ['Plastic', 'Batteries'] },
    { name: 'Eastside Recycling Point', lat: 29.760427, lng: -95.369804, materials: ['Paper', 'Glass'] },
    { name: 'Northside Eco Center', lat: 47.606209, lng: -122.332071, materials: ['Electronics', 'Metal', 'Plastic'] },
  ];

  function createMap(center) {
    // Clear existing map content
    mapContainer.innerHTML = '';

    // Create a basic map layout with simple markers
    const mapEl = document.createElement('div');
    mapEl.style.width = '100%';
    mapEl.style.height = '400px';
    mapEl.style.position = 'relative';
    mapEl.style.backgroundColor = '#e0f7e9';
    mapEl.style.border = '2px solid #4CAF50';
    mapEl.style.borderRadius = '8px';
    mapEl.style.overflow = 'hidden';
    mapContainer.appendChild(mapEl);

    // Simple coordinate conversion for demonstration (not geospatial accurate)
    // Assuming map bounds roughly lat: 25 to 50, lng: -125 to -65
    const latMin = 25;
    const latMax = 50;
    const lngMin = -125;
    const lngMax = -65;
    const width = mapEl.clientWidth;
    const height = mapEl.clientHeight;

    function coordToPosition(lat, lng) {
      const x = ((lng - lngMin) / (lngMax - lngMin)) * width;
      const y = height - ((lat - latMin) / (latMax - latMin)) * height;
      return { x, y };
    }

    // Render markers
    recyclingCenters.forEach(centerObj => {
      const pos = coordToPosition(centerObj.lat, centerObj.lng);
      const marker = document.createElement('div');
      marker.className = 'map-marker';
      marker.style.position = 'absolute';
      marker.style.left = `${pos.x - 10}px`;
      marker.style.top = `${pos.y - 20}px`;
      marker.style.width = '20px';
      marker.style.height = '20px';
      marker.style.backgroundColor = '#4CAF50';
      marker.style.borderRadius = '50%';
      marker.style.cursor = 'pointer';
      marker.title = centerObj.name;

      marker.addEventListener('click', () => {
        showCenterInfo(centerObj);
      });

      mapEl.appendChild(marker);
    });

    // Marker for user location
    if (center) {
      const userPos = coordToPosition(center.lat, center.lng);
      const userMarker = document.createElement('div');
      userMarker.className = 'user-location-marker';
      userMarker.style.position = 'absolute';
      userMarker.style.left = `${userPos.x - 10}px`;
      userMarker.style.top = `${userPos.y - 20}px`;
      userMarker.style.width = '20px';
      userMarker.style.height = '20px';
      userMarker.style.backgroundColor = '#FF5722';
      userMarker.style.borderRadius = '50%';
      userMarker.style.border = '2px solid white';
      userMarker.title = 'Your Location';
      mapEl.appendChild(userMarker);
    }
  }

  function showCenterInfo(centerObj) {
    locationResults.innerHTML = `
      <h3>${centerObj.name}</h3>
      <p><strong>Materials Accepted:</strong> ${centerObj.materials.join(', ')}</p>
    `;
  }

  function findNearestCenter(lat, lng) {
    // Calculate simple euclidean distance for nearest center
    let nearest = null;
    let minDist = Number.MAX_VALUE;
    recyclingCenters.forEach(centerObj => {
      const dist = Math.sqrt(Math.pow(centerObj.lat - lat, 2) + Math.pow(centerObj.lng - lng, 2));
      if (dist < minDist) {
        minDist = dist;
        nearest = centerObj;
      }
    });
    return nearest;
  }

  function geocodeAddress(address) {
    // For demonstration, mock geocode with simple lookups
    const lookup = {
      'new york': { lat: 40.712776, lng: -74.005974 },
      'los angeles': { lat: 34.052235, lng: -118.243683 },
      'chicago': { lat: 41.878113, lng: -87.629799 },
      'houston': { lat: 29.760427, lng: -95.369804 },
      'seattle': { lat: 47.606209, lng: -122.332071 },
    };
    const key = address.trim().toLowerCase();
    return lookup[key] || null;
  }

  locateBtn.addEventListener('click', () => {
    const address = locationInput.value;
    if (!address) {
      alert('Please enter an address or zip code.');
      return;
    }

    const coords = geocodeAddress(address);
    if (!coords) {
      locationResults.textContent = 'Location not found. Please enter a valid city name like New York or Seattle.';
      createMap(defaultCenter);
      return;
    }

    const nearestCenter = findNearestCenter(coords.lat, coords.lng);
    createMap(coords);
    if (nearestCenter) {
      showCenterInfo(nearestCenter);
    } else {
      locationResults.textContent = 'No recycling centers found near your location.';
    }
  });

  // Attempt to get user geolocation
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const userCoords = {
          lat: position.coords.latitude,
          lng: position.coords.longitude
        };
        createMap(userCoords);
        const nearestCenter = findNearestCenter(userCoords.lat, userCoords.lng);
        if (nearestCenter) {
          showCenterInfo(nearestCenter);
        } else {
          locationResults.textContent = 'No recycling centers found near your location.';
        }
      },
      () => {
        createMap(defaultCenter);
        locationResults.textContent = 'Geolocation denied or unavailable. Enter a location above to find recycling centers.';
      }
    );
  } else {
    createMap(defaultCenter);
    locationResults.textContent = 'Geolocation not supported. Enter a location above to find recycling centers.';
  }

  // Initial map render
  createMap(defaultCenter);
});
