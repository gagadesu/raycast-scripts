import { Toast, showToast } from "@raycast/api";

const OVERLAY_STARTUP_DELAY_MS = 300;

export default async function Command() {
  try {
    const { handler } = await import("swift:../swift/MyExecutable");
    Promise.resolve(handler()).catch(async (error) => {
      await showToast({ title: "Clean Mode failed", message: String(error), style: Toast.Style.Failure });
    });

    // Keep the command alive briefly so the native process can create every
    // overlay window before Raycast finishes this no-view command.
    await new Promise((resolve) => setTimeout(resolve, OVERLAY_STARTUP_DELAY_MS));
  } catch (error) {
    await showToast({ title: "Clean Mode failed", message: String(error), style: Toast.Style.Failure });
  }
}
