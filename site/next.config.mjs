const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

export default {
  output: "export",
  basePath,
  devIndicators: false,
  trailingSlash: true,
};
