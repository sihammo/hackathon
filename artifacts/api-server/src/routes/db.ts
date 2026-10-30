import { Router, type Request, type Response } from "express";
import mongoose from "mongoose";
import { isMongoConnected, seedDatabase } from "../lib/db";
import {
  UserModel,
  DeviceModel,
  AlertModel,
  HotspotModel,
  InsurancePartnerModel,
} from "../models";

const router = Router();

// GET /api/db/status
router.get("/status", async (req: Request, res: Response) => {
  try {
    const connected = isMongoConnected();
    const readyState = mongoose.connection.readyState;
    const states = ["disconnected", "connected", "connecting", "disconnecting"];

    let stats = {
      users: 0,
      devices: 0,
      alerts: 0,
      hotspots: 0,
      insurancePartners: 0,
    };

    if (connected) {
      stats = {
        users: await UserModel.countDocuments(),
        devices: await DeviceModel.countDocuments(),
        alerts: await AlertModel.countDocuments(),
        hotspots: await HotspotModel.countDocuments(),
        insurancePartners: await InsurancePartnerModel.countDocuments(),
      };
    }

    return res.json({
      success: true,
      mongoConnected: connected,
      connectionState: states[readyState] || "unknown",
      databaseName: mongoose.connection.name || "slamtek_db",
      host: mongoose.connection.host || "in-memory-fallback",
      collections: stats,
      configuredUri: Boolean(process.env.MONGODB_URI),
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/db/seed (Manual trigger)
router.post("/seed", async (req: Request, res: Response) => {
  try {
    await seedDatabase();
    return res.json({
      success: true,
      message: "Toutes les collections ont été initialisées avec succès dans MongoDB!",
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
