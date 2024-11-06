/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    const baseUrl = process.env.NEXT_PUBLIC_API_URL;
    const port = process.env.NEXT_PUBLIC_API_PORT;
    
    if (!baseUrl || !port) {
      console.warn('Warning: API URL or PORT not configured in environment variables');
    }
    
    return [
      {
        source: '/api/:path*',
        destination: `${baseUrl}:${port}/:path*`
      }
    ]
  }
}

module.exports = nextConfig