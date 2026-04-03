import { ApiResponse } from "../utils/Apiresponse.js";
import { asyncHandler } from "../utils/AsyncHandler.js";

const pingServer = asyncHandler(async (req, res) => {
    // We don't query the database here at all! 
    // We just immediately send back a 200 OK success message.
    return res.status(200).json(
        new ApiResponse(200, {}, "SERVER IS AWAKE AND RUNNING SMOOTHLY!")
    );
});

export { pingServer };