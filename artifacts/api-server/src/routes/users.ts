import { Router, type Request, type Response } from "express";
import { UserModel } from "../models";
import { SEED_USERS, isMongoConnected } from "../lib/db";
import { getAllPgUsers, getPgUserByUid } from "../lib/postgres";

const router = Router();
let memoryUsers = [...SEED_USERS];

// GET /api/users
router.get("/", async (req: Request, res: Response) => {
  try {
    const { role, wilaya } = req.query;

    // 1. Try Supabase PostgreSQL
    try {
      const pgUsers = await getAllPgUsers(
        role ? String(role) : undefined,
        wilaya ? Number(wilaya) : undefined
      );
      if (pgUsers.length > 0) return res.json(pgUsers);
    } catch {
      // Fallback
    }

    // 2. Try MongoDB
    if (isMongoConnected()) {
      const query: any = {};
      if (role) query.role = role;
      if (wilaya) query.wilayaCode = Number(wilaya);
      const users = await UserModel.find(query).select("-password").sort({ createdAt: -1 });
      return res.json(users);
    }

    // 3. Fallback memory
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
    const uid = String(req.params.uid);

    try {
      const pgUser = await getPgUserByUid(uid);
      if (pgUser) return res.json(pgUser);
    } catch {
      // Fallback
    }

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

export default router;
