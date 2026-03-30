export function formatTime(milliseconds: number) {
    const seconds = Math.floor(milliseconds / 1000) % 60;
    const minutes = Math.floor(milliseconds / (1000 * 60)) % 60;
    const hours = Math.floor(milliseconds / (1000 * 60 * 60)) % 24;
    const days = Math.floor(milliseconds / (1000 * 60 * 60 * 24));
    const parts = [];
    if (days > 0) {
        parts.push(`${days}d`);
    }
    if (days > 0 || hours > 0) {
        parts.push(`${String(hours).padStart(2, "0")}h`);
    }
    if (days > 0 || hours > 0 || minutes > 0) {
        parts.push(`${String(minutes).padStart(2, "0")}m`);
    }
    if (days > 0 || hours > 0 || minutes > 0 || seconds > 0) {
        parts.push(`${String(seconds).padStart(2, "0")}s`);
    }
    return parts.join(" ");
}