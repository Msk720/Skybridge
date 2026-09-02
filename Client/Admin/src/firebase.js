import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
    apiKey: "AIzaSyBAz_ie-D-gdUx1vUQVHVn6gKiGqM2YYyQ",
    authDomain: "sdp1-b91a6.firebaseapp.com",
    projectId: "sdp1-b91a6",
    storageBucket: "sdp1-b91a6.firebasestorage.app",
    messagingSenderId: "129758844450",
    appId: "1:129758844450:web:4515a5f0b77e49bec01c7b",
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);