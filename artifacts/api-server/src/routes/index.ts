import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import usersRouter from "./users";
import devicesRouter from "./devices";
import alertsRouter from "./alerts";
import hotspotsRouter from "./hotspots";
import insuranceRouter from "./insurance";
import wilayasRouter from "./wilayas";
import dbRouter from "./db";

const router: IRouter = Router();

router.use(healthRouter);
router.use("/auth", authRouter);
router.use("/users", usersRouter);
router.use("/devices", devicesRouter);
router.use("/alerts", alertsRouter);
router.use("/hotspots", hotspotsRouter);
router.use("/insurance", insuranceRouter);
router.use("/wilayas", wilayasRouter);
router.use("/db", dbRouter);

export default router;
