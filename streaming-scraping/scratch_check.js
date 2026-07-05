import { gotScraping } from 'got-scraping';

const BASE_URL = 'https://z2.idlixku.com';
const idlixHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

async function test() {
  try {
    const url = `${BASE_URL}/api/series/family-guy-1999`;
    console.log("Fetching:", url);
    const res = await gotScraping({
      url,
      headers: idlixHeaders,
      useHeaderGenerator: false,
    });
    console.log("Status:", res.statusCode);
    if (res.statusCode === 200) {
      const data = JSON.parse(res.body);
      console.log("Seasons:", data.seasons?.map(s => ({ id: s.id, seasonNumber: s.seasonNumber, name: s.name })));
    } else {
      console.log("Failed to fetch.");
    }
  } catch (err) {
    console.error("Error:", err.message);
  }
}

test();
