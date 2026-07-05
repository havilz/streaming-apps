import { gotScraping } from "got-scraping";

const BASE_URL = "https://z2.idlixku.com";
const headers = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

async function testQuery(url) {
  try {
    const res = await gotScraping({
      url,
      headers,
      useHeaderGenerator: false,
    });
    const data = JSON.parse(res.body);
    console.log(`\nGET ${url}`);
    console.log(`Status: ${res.statusCode}`);
    console.log(`Total items found: ${data.pagination?.total || data.total}`);
    if (data.data && data.data[0]) {
      console.log(`First item title: ${data.data[0].title} | country: ${data.data[0].country}`);
    }
  } catch (err) {
    console.log(`\nGET ${url} - Error:`, err.message);
  }
}

async function main() {
  // Test if target API supports filtering on /api/movies or /api/series
  await testQuery(`${BASE_URL}/api/series?network=netflix&limit=5`);
  await testQuery(`${BASE_URL}/api/series?network=213&limit=5`); // Netflix network TMDB ID is 213
  await testQuery(`${BASE_URL}/api/series?country=JP&limit=5`);
  await testQuery(`${BASE_URL}/api/movies?country=KR&limit=5`);
  await testQuery(`${BASE_URL}/api/movies?genre=action&limit=5`);
  await testQuery(`${BASE_URL}/api/movies?year=2024&limit=5`);
}

main().catch(console.error);
