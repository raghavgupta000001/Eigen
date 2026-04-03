import { Event } from "../models/event.model.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/Apiresponse.js";
import { asyncHandler } from "../utils/AsyncHandler.js";
import { Attendance } from "../models/attendance.model.js";
import { User } from "../models/user.model.js";
import { Team } from "../models/team.model.js"; 
const ALLOWED_CLUBS = [
    'CODEBASE', 'KERNEL', 'ARC ROBOTICS', 'ALGORITHMUS', 
    'CYPHER', 'GDF', 'GFG', 'TGCC', 'TECHKNOW'
];

const createEvent = asyncHandler(async (req, res) => {
    const { 
        title, clubName, description, date, startTime, 
        endTime, location, participationType, minTeamSize, maxTeamSize 
    } = req.body;

    // 1. Text Field Validation
    if (!title || !clubName || !date || !startTime || !endTime) {
        throw new ApiError(400, "TITLE, CLUBNAME, DATE, START TIME, AND END TIME ARE REQUIRED");
    }

    // 2. Image Validation 
    const imageLocalPath = req.file?.path;
    if (!imageLocalPath) {
        throw new ApiError(400, "EVENT IMAGE (POSTER) IS REQUIRED");
    }

    const upperClubName = clubName.toUpperCase();
    const upperTitle = title.toUpperCase().trim();

    // 3. Club & Role Validation
    if (!ALLOWED_CLUBS.includes(upperClubName)) {
        throw new ApiError(400, `INVALID CLUB. ALLOWED: ${ALLOWED_CLUBS.join(', ')}`);
    }

    if (!req.user.roles.includes('CLUB_MEMBER') && !req.user.roles.includes('ADMIN')) {
        throw new ApiError(403, "ONLY CLUB MEMBERS OR ADMINS CAN CREATE EVENTS");
    }

    if (!req.user.clubMemberships.includes(upperClubName) && !req.user.roles.includes('ADMIN')) {
        throw new ApiError(403, `NOT AUTHORIZED FOR ${upperClubName}`);
    }

    // 4. Team Logic Parsing
    let pType = participationType ? participationType.toUpperCase() : 'INDIVIDUAL';
    let finalMin = 1, finalMax = 1;

    if (pType === 'TEAM') {
        finalMin = parseInt(minTeamSize, 10) || 2;
        finalMax = parseInt(maxTeamSize, 10) || 2;
        if (finalMin < 2) throw new ApiError(400, "MINIMUM TEAM SIZE MUST BE AT LEAST 2");
        if (finalMin > finalMax) throw new ApiError(400, "MIN SIZE CANNOT BE GREATER THAN MAX SIZE");
    }

    // ==========================================
    // 5. NEW: CHECK FOR DUPLICATE EVENT
    // ==========================================
    const existingEvent = await Event.findOne({
        title: upperTitle,
        clubName: upperClubName
    });

    if (existingEvent) {
        throw new ApiError(409, `AN EVENT NAMED '${upperTitle}' ALREADY EXISTS FOR ${upperClubName}`);
    }
    // ==========================================

    // 6. Create Event in Database
    const newEvent = await Event.create({
        title: upperTitle,
        clubName: upperClubName,
        description,
        date,
        startTime,
        endTime,
        location,
        participationType: pType,
        minTeamSize: finalMin,
        maxTeamSize: finalMax,
        image: imageLocalPath, 
        createdBy: req.user._id
    });

    return res.status(201).json(
        new ApiResponse(201, newEvent, `EVENT '${newEvent.title}' CREATED SUCCESSFULLY`)
    );
});

const registerForEvent = asyncHandler(async (req, res) => {
    // We take the eventId from the URL parameters (e.g., /api/events/:eventId/register)
    const { eventId } = req.params;

    // 1. Find the Event
    const event = await Event.findById(eventId);
    if (!event) {
        throw new ApiError(404, "EVENT NOT FOUND");
    }

    // 2. Prevent Individual Registration for Team Events
    // Since you added Team logic, we must ensure solo students don't bypass it
    if (event.participationType === 'TEAM') {
        throw new ApiError(400, "THIS IS A TEAM EVENT. PLEASE USE THE TEAM REGISTRATION PORTAL.");
    }

    // 3. Time Validation (Registration Deadline)
    // Prevents students from registering for an event that happened yesterday
    const currentDate = new Date();
    const eventDate = new Date(event.date);

    // Stripping the time to strictly compare the calendar dates
    if (currentDate.setHours(0,0,0,0) > eventDate.setHours(0,0,0,0)) {
        throw new ApiError(400, "REGISTRATION CLOSED: EVENT HAS ALREADY ENDED");
    }

    // 4. Check for Existing Registration
    // This prevents a user from double-clicking and creating two QR records
    const existingAttendance = await Attendance.findOne({
        user: req.user._id,
        event: event._id
    });

    if (existingAttendance) {
        throw new ApiError(400, `YOU ARE ALREADY REGISTERED FOR ${event.title}`);
    }

    // 5. Create the Attendance Record
    const attendance = await Attendance.create({
        user: req.user._id,
        event: event._id,
        status: "REGISTERED"
    });

    return res.status(201).json(
        new ApiResponse(201, 
            { 
                eventTitle: event.title, 
                status: attendance.status,
                qrCodeIdentifier: req.user.qrCodeIdentifier // Frontend can use this to render the QR instantly
            }, 
            `SUCCESSFULLY REGISTERED FOR ${event.title}`
        )
    );
});

const registerTeamForEvent = asyncHandler(async (req, res) => {
    const { eventId } = req.params;
    const { teamName, memberEmails } = req.body; 
    // Expects memberEmails to be an array: ["friend1@iiitkota.ac.in", "friend2@iiitkota.ac.in"]

    // 1. Basic Validation
    if (!teamName || !memberEmails || !Array.isArray(memberEmails)) {
        throw new ApiError(400, "TEAM NAME AND AN ARRAY OF MEMBER EMAILS ARE REQUIRED");
    }

    // 2. Find the Event & Validate Type
    const event = await Event.findById(eventId);
    if (!event) {
        throw new ApiError(404, "EVENT NOT FOUND");
    }

    if (event.participationType !== 'TEAM') {
        throw new ApiError(400, "THIS IS AN INDIVIDUAL EVENT. TEAM REGISTRATION IS NOT ALLOWED.");
    }

    // 3. Prepare the Emails List (Ensure uppercase and include the leader)
    const formattedEmails = memberEmails.map(email => email.toUpperCase());
    
    // Automatically add the leader (the person making the request) if they forgot to include themselves
    if (!formattedEmails.includes(req.user.email)) {
        formattedEmails.push(req.user.email);
    }

    // 4. Validate Team Size
    if (formattedEmails.length < event.minTeamSize || formattedEmails.length > event.maxTeamSize) {
        throw new ApiError(400, `TEAM SIZE MUST BE BETWEEN ${event.minTeamSize} AND ${event.maxTeamSize} MEMBERS`);
    }

    // 5. Verify all members exist in the Database
    // (This ensures they have logged in via Google at least once and are verified IIIT KOTA students)
    const members = await User.find({ email: { $in: formattedEmails } });

    if (members.length !== formattedEmails.length) {
        throw new ApiError(400, "SOME MEMBERS ARE NOT REGISTERED ON THE PLATFORM. ASK THEM TO LOGIN ONCE BEFORE FORMING THE TEAM.");
    }

    const memberIds = members.map(member => member._id);

    // 6. Check for Double Registration (Crucial for Teams)
    // We must ensure none of these users are already registered for this event (either solo or in another team)
    const existingAttendance = await Attendance.find({ 
        event: event._id, 
        user: { $in: memberIds } 
    }).populate("user", "name email");

    if (existingAttendance.length > 0) {
        const alreadyRegisteredNames = existingAttendance.map(att => att.user.name).join(", ");
        throw new ApiError(400, `THE FOLLOWING MEMBERS ARE ALREADY REGISTERED FOR THIS EVENT: ${alreadyRegisteredNames}`);
    }

    // 7. Check if Team Name is already taken for this specific event
    const existingTeam = await Team.findOne({ 
        teamName: teamName.toUpperCase(), 
        event: event._id 
    });

    if (existingTeam) {
        throw new ApiError(400, "THIS TEAM NAME IS ALREADY TAKEN FOR THIS EVENT. PLEASE CHOOSE ANOTHER.");
    }

    // 8. Create the Team Document
    const newTeam = await Team.create({
        teamName: teamName.toUpperCase(),
        event: event._id,
        leader: req.user._id, // The user making the API request is automatically the leader
        members: memberIds,
        teamSize: memberIds.length
    });

    // 9. Bulk Create Attendance Records
    // We use insertMany for performance so we don't have to hit the DB in a loop
    const attendanceDocs = memberIds.map(id => ({
        user: id,
        event: event._id,
        status: "REGISTERED"
    }));

    await Attendance.insertMany(attendanceDocs);

    return res.status(201).json(
        new ApiResponse(201, 
            { 
                team: newTeam.teamName,
                size: newTeam.teamSize,
                leader: req.user.name 
            }, 
            `TEAM '${newTeam.teamName}' SUCCESSFULLY REGISTERED FOR ${event.title}`
        )
    );
});

const getMyClubEvents = asyncHandler(async (req, res) => {
    // 1. Grab the user's club array from the verified JWT token
    const userClubs = req.user.clubMemberships;

    // 2. If they aren't in any clubs, just return an empty array so the app doesn't crash
    if (!userClubs || userClubs.length === 0) {
        return res.status(200).json(
            new ApiResponse(200, [], "User is not a member of any clubs.")
        );
    }

    // 3. Find all events where the 'clubName' matches ANY of the clubs in the user's array
    // We also use .sort({ date: 1 }) to order them so the soonest events show up first!
    const events = await Event.find({
        clubName: { $in: userClubs }
    }).sort({ date: 1 });

    // 4. Send the list back to the Flutter app
    return res.status(200).json(
        new ApiResponse(200, events, "Successfully fetched events for your clubs.")
    );
});

const getEventAttendees = asyncHandler(async (req, res) => {
    const { eventId } = req.params;

    const event = await Event.findById(eventId);
    if (!event) throw new ApiError(404, "Event not found");

    // THE FIX: If participationType is missing (old events), treat it as INDIVIDUAL
    const pType = event.participationType || 'INDIVIDUAL';

    // ==========================================
    // PATH A: INDIVIDUAL EVENT
    // ==========================================
    if (pType === 'INDIVIDUAL') {
        const attendees = await Attendance.find({ event: eventId })
            .populate("user", "name email qrCodeIdentifier");
        
        return res.status(200).json(
            new ApiResponse(200, { type: 'INDIVIDUAL', data: attendees }, "Individual attendees fetched")
        );
    }
    
    // ==========================================
    // PATH B: TEAM EVENT
    // ==========================================
    else {
        // 1. Fetch all teams for this event
        const teams = await Team.find({ event: eventId })
            .populate("leader", "name email")
            .populate("members", "name email qrCodeIdentifier");

        // 2. Fetch all attendance records to figure out who is IN/OUT
        const attendances = await Attendance.find({ event: eventId });
        
        // Create a fast lookup map for statuses (userId -> status)
        const statusMap = {};
        attendances.forEach(att => {
            statusMap[att.user.toString()] = att.status;
        });

        // 3. Format the data to group members under their teams
        const formattedTeams = teams.map(team => {
            let isTeamIn = false; // We consider a team "IN" if at least one member is scanned IN

            const membersWithStatus = team.members.map(member => {
                const status = statusMap[member._id.toString()] || 'REGISTERED';
                if (status === 'IN') isTeamIn = true; 
                
                return {
                    _id: member._id,
                    name: member.name,
                    email: member.email,
                    status: status
                };
            });

            return {
                _id: team._id,
                teamName: team.teamName,
                leaderName: team.leader ? team.leader.name : 'Unknown',
                teamSize: team.teamSize,
                teamStatus: isTeamIn ? 'IN' : 'REGISTERED',
                members: membersWithStatus
            };
        });

        return res.status(200).json(
            new ApiResponse(200, { type: 'TEAM', data: formattedTeams }, "Team attendees fetched")
        );
    }
});

const scanQrCode = asyncHandler(async (req, res) => {
    const { eventId } = req.params;
    const { qrCodeIdentifier, scanType } = req.body; // scanType will be 'IN' or 'OUT'

    if (!qrCodeIdentifier || !scanType) {
        throw new ApiError(400, "QR Code and Scan Type are required.");
    }

    // 1. Find the User by their unique QR string
    const student = await User.findOne({ qrCodeIdentifier });
    if (!student) {
        throw new ApiError(404, "INVALID QR: Student not found in database.");
    }

    // 2. Check if they are registered for this specific event
    const attendanceRecord = await Attendance.findOne({ user: student._id, event: eventId });
    if (!attendanceRecord) {
        throw new ApiError(403, `ACCESS DENIED: ${student.name} is NOT registered for this event.`);
    }

    // 3. Prevent double-scanning (e.g., scanning IN when already IN)
    if (attendanceRecord.status === scanType) {
        throw new ApiError(400, `DOUBLE SCAN: ${student.name} is already marked ${scanType}.`);
    }

    // 4. Update the attendance status and history
    attendanceRecord.status = scanType;
    attendanceRecord.scanHistory.push({
        type: scanType,
        scannedBy: req.user._id // The volunteer making the scan
    });

    await attendanceRecord.save();

    // 5. Send a triumphant success message back to the phone!
    return res.status(200).json(
        new ApiResponse(200, { studentName: student.name }, `SUCCESS: ${student.name} marked ${scanType}!`)
    );
});

export{
    createEvent,
    registerForEvent,
    registerTeamForEvent,
    getMyClubEvents,
    getEventAttendees,
    scanQrCode
}