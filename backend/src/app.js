import cookieParser from 'cookie-parser';
import cors from 'cors';
import express from 'express';
import userRouter from "./routes/user.routes.js"
import eventRouter from "./routes/event.routes.js"
import teamRouter from "./routes/team.routes.js"
import pingRouter from './routes/ping.routes.js';

const app = express();
app.use(cookieParser())

app.use(cors({
    origin:"http://localhost:5173",
    credentials:true,
    methods:["GET","POST","PUT","DELETE","PATCH","OPTIONS"],
    allowedHeaders:["Content-Type","Authorization","X-Requested-With","Accept"]
}))

app.use(express.json({
    limit:"16kb"
}))

app.use(express.urlencoded({
    limit:"16kb",
    extended:true
}))

app.use(express.static("public"))

// --- 1. ROUTES ---
app.use("/api/v1/users" , userRouter)
app.use("/api/v1/events" , eventRouter)
app.use("/api/v1/teams" , teamRouter)
app.use("/api/v1/ping" , pingRouter)
// --- 2. GLOBAL ERROR HANDLER (MUST BE EXACTLY HERE) ---
// This acts as the final safety net. If any route above throws an ApiError, 
// it falls into this function, which forces Express to send clean JSON instead of an HTML crash page.
app.use((err, req, res, next) => {
    const statusCode = err.statusCode || 500;
    const message = err.message || "Internal Server Error";

    return res.status(statusCode).json({
        success: false,
        statusCode: statusCode,
        message: message,
        // Optional: Only show the full red error text in the console if on localhost
        stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
    });
});

export {app}