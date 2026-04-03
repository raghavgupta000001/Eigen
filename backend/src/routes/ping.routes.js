import { Router } from "express";
import { pingServer } from "../controllers/ping.controller.js";

const router = Router();

// This creates a GET route at the root of whatever this router is attached to
router.route("/").get(pingServer);

export default router;