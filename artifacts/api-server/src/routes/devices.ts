import { Router, type Request, type Response } from "express";
import { DeviceModel } from "../models";
import { SEED_DEVICES, isMongoConnected } from "../lib/db";

const router = Router();
let memoryDevices = [...SEED_DEVICES];

// GET /api/devices
router.get("/", async (req: Request, res: Response) => {
  try {
    const { userId } = req.query;

    if (isMongoConnected()) {
      const query = userId ? { userId } : {};
      const devices = await DeviceModel.find(query).sort({ lastSeen: -1 });
      return res.json(devices);
    }

    let filtered = memoryDevices;
    if (userId) filtered = filtered.filter((d) => d.userId === userId);
    return res.json(filtered);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/devices/:id
router.get("/:id", async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    if (isMongoConnected()) {
      const device = await DeviceModel.findOne({ id });
      if (!device) return res.status(404).json({ error: "Device not found" });
      return res.json(device);
    }

    const device = memoryDevices.find((d) => d.id === id);
    if (!device) return res.status(404).json({ error: "Device not found" });
    return res.json(device);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/devices/telemetry (From ESP32 IoT Box)
router.post("/telemetry", async (req: Request, res: Response) => {
  try {
    const { id, batteryLevel, signalStrength, connected } = req.body;

    if (!id) return res.status(400).json({ error: "Device ID is required" });

    const update = {
      batteryLevel: batteryLevel ?? 95,
      signalStrength: signalStrength ?? -70,
      connected: connected ?? true,
      lastSeen: new Date(),
    };

    if (isMongoConnected()) {
      const updated = await DeviceModel.findOneAndUpdate({ id }, update, {
        new: true,
      });
      return res.json({ success: true, device: updated });
    }

    const index = memoryDevices.findIndex((d) => d.id === id);
    if (index !== -1) {
      memoryDevices[index] = { ...memoryDevices[index], ...update } as any;
      return res.json({ success: true, device: memoryDevices[index] });
    }

    return res.json({ success: true });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
