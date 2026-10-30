import express, { type Express } from "express";
import cors from "cors";
import pinoHttp from "pino-http";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import router from "./routes";
import { logger } from "./lib/logger";

const app: Express = express();

app.use(
  pinoHttp({
    logger,
    serializers: {
      req(req) {
        return {
          id: req.id,
          method: req.method,
          url: req.url?.split("?")[0],
        };
      },
      res(res) {
        return {
          statusCode: res.statusCode,
        };
      },
    },
  }),
);
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// API endpoints
app.use("/api", router);

// Serve frontend static assets (Flutter Web)
const currentDir = path.dirname(fileURLToPath(import.meta.url));
const candidates = [
  path.resolve(process.cwd(), "public"),
  path.resolve(process.cwd(), "../../public"),
  path.resolve(process.cwd(), "../public"),
  path.resolve(currentDir, "../../../public"),
  path.resolve(currentDir, "../../public"),
  path.resolve(currentDir, "../public"),
];
const publicDir = candidates.find((dir) =>
  fs.existsSync(path.join(dir, "index.html")),
);

if (publicDir) {
  logger.info({ publicDir }, "Serving Slamtek Web frontend");
  app.use(express.static(publicDir));
  app.use((req, res, next) => {
    if (req.method === "GET" && !req.path.startsWith("/api")) {
      return res.sendFile(path.join(publicDir, "index.html"));
    }
    next();
  });
} else {
  logger.warn(
    "Public directory with index.html not found; running in API-only mode",
  );
}

export default app;
