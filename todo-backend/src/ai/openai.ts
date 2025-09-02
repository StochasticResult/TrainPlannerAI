import OpenAI from "openai";
import dotenv from "dotenv";
dotenv.config();

const apiKey = process.env.OPENAI_API_KEY || "";
const project = process.env.OPENAI_PROJECT_ID || "default";

export const openai = new OpenAI({ apiKey, project });

