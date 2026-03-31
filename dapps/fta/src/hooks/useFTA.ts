import { useContext } from "react";
import { FTAContext } from "../providers/FTAProvider";
import { FTAContextType } from "../types/fta";

export function useFTA(): FTAContextType {
    const context = useContext(FTAContext);
    if (!context) {
        throw new Error(
            "useFTA must be used within an FTAProvider",
        );
    }
    return context;
}