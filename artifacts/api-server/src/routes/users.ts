import { Router, type Request, type Response } from "express";
import { UserModel } from "../models";
import { SEED_USERS, isMongoConnected } from "../lib/db";

const router = Router();
let memoryUsers = [...SEED_USERS];

// GET /api/users
router.get("/", async (req: Request, res: Response) => {
  try {
    const { role, wilaya } = req.query;

    if (isMongoConnected()) {
      const query: any = {};
      if (role) query.role = role;
      if (wilaya) query.wilayaCode = Number(wilaya);
      const users = await UserModel.find(query).select("-password").sort({ createdAt: -1 });
      return res.json(users);
    }

    let filtered = memoryUsers;
    if (role) filtered = filtered.filter((u) => u.role === role);
    if (wilaya) filtered = filtered.filter((u) => u.wilayaCode === Number(wilaya));
    return res.json(filtered.map(({ password, ...u }) => u));
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/users/:uid
router.get("/:uid", async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;

    if (isMongoConnected()) {
      const user = await UserModel.findOne({ uid }).select("-password");
      if (!user) return res.status(404).json({ error: "User not found" });
      return res.json(user);
    }

    const user = memoryUsers.find((u) => u.uid === uid);
    if (!user) return res.status(404).json({ error: "User not found" });
    const { password, ...safe } = user;
    return res.json(safe);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// PUT /api/users/:uid
router.put("/:uid", async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;
    const updates = req.body;
    delete updates.password; // Do not update password through this route

    if (isMongoConnected()) {
      const updated = await UserModel.findOneAndUpdate({ uid }, updates, {
        new: true,
      }).select("-password");
      if (!updated) return res.status(404).json({ error: "User not found" });
      return res.json(updated);
    }

    const index = memoryUsers.findIndex((u) => u.uid === uid);
    if (index === -1) return res.status(404).json({ error: "User not found" });
    memoryUsers[index] = { ...memoryUsers[index], ...updates };
    const { password, ...safe } = memoryUsers[index];
    return res.json(safe);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
