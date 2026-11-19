import { createRoot } from "react-dom/client";
import { AcquisitionChat } from "./app/chat-tab/AcquisitionChat";
import "./app/globals.css";

type NativeBridge = Window & {
  webkit?: { messageHandlers?: { sokerAcquisitionReady?: { postMessage?: (value: unknown) => void } } };
};

const bridge = (window as NativeBridge).webkit?.messageHandlers?.sokerAcquisitionReady;
const embedded = new URLSearchParams(window.location.search).get("embedded") === "1"
  && typeof bridge?.postMessage === "function";

createRoot(document.getElementById("root")!).render(<AcquisitionChat embedded={embedded} />);
