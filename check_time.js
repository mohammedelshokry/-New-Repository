const https = require('https');
https.get('https://timeapi.io/api/Time/current/zone?timeZone=UTC', (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => console.log(JSON.parse(data).dateTime));
});
