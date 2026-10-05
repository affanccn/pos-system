async function testCors() {
  try {
    const res = await fetch('http://localhost:3000/api/v1/auth/login-pin', {
      method: 'OPTIONS',
      headers: { 
        'Origin': 'http://localhost:8080',
        'Access-Control-Request-Method': 'POST',
      }
    });
    console.log('Status:', res.status);
    console.log('Headers:', Object.fromEntries(res.headers.entries()));
  } catch (err) {
    console.error('Fetch error:', err);
  }
}
testCors();
