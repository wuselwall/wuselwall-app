package ch.goomba.wuselwall

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityCheckPreset
import com.google.android.apps.common.testing.accessibility.framework.uielement.AccessibilityHierarchyAndroid
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Audits accessibility-service nodes, including Flutter's virtual descendants. */
@RunWith(AndroidJUnit4::class)
class QualificationAuditTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val automation = instrumentation.uiAutomation
    private val context = instrumentation.targetContext

    private fun request(path: String, payload: JSONObject? = null): JSONObject {
        val connection = URL("http://127.0.0.1:18765/$path").openConnection() as HttpURLConnection
        connection.connectTimeout = 2000
        connection.readTimeout = 5000
        if (payload != null) {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write(payload.toString().toByteArray()) }
        }
        return try { JSONObject(connection.inputStream.bufferedReader().use { it.readText() }) }
        finally { connection.disconnect() }
    }

    private fun ready(): JSONObject {
        repeat(180) {
            try { val state = request("state"); if (state.optBoolean("ready") || state.optBoolean("done")) return state }
            catch (_: java.io.IOException) { }
            Thread.sleep(500)
        }
        error("Flutter audit fixture did not become ready")
    }

    private fun find(node: AccessibilityNodeInfo, id: String): AccessibilityNodeInfo? {
        if (node.viewIdResourceName == id || node.viewIdResourceName?.endsWith("/$id") == true) return node
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            find(child, id)?.let { return it }
        }
        return null
    }

    private fun labelCount(node: AccessibilityNodeInfo): Int {
        var count = if (!node.text.isNullOrBlank() || !node.contentDescription.isNullOrBlank()) 1 else 0
        for (i in 0 until node.childCount) node.getChild(i)?.let { count += labelCount(it) }
        return count
    }

    private fun semantics(node: AccessibilityNodeInfo): JSONObject {
        val children = JSONArray()
        for (i in 0 until node.childCount) node.getChild(i)?.let { children.put(semantics(it)) }
        return JSONObject().put("class", node.className?.toString() ?: "")
            .put("identifier", node.viewIdResourceName ?: "").put("label", node.contentDescription?.toString() ?: "")
            .put("text", node.text?.toString() ?: "").put("hint", if (Build.VERSION.SDK_INT >= 26) node.hintText?.toString() ?: "" else "")
            .put("enabled", node.isEnabled).put("clickable", node.isClickable).put("checkable", node.isCheckable)
            .put("checked", node.isChecked).put("selected", node.isSelected).put("children", children)
    }

    @Test fun auditFlutterSemantics() {
        // Request interactive windows and force services semantics before Flutter launches.
        val info = automation.serviceInfo
        info.flags = info.flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
            AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        automation.serviceInfo = info
        context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        var state: JSONObject? = null
        repeat(120) {
            if (state == null) try { state = request("state") } catch (_: java.io.IOException) { Thread.sleep(500) }
        }
        assertNotNull("Audit bridge never started", state)
        var detector = false
        var keyboard = false
        var frameworkErrorCount = 0
        var cases = 0
        while (true) {
            request("next", JSONObject())
            val sample = ready()
            if (sample.optBoolean("done")) break
            val id = sample.getString("id")
            val root = automation.rootInActiveWindow ?: error("No Android accessibility window")
            assertEquals(context.packageName, root.packageName.toString())
            val issues = JSONArray()
            if (id == "detector-keyboard") {
                val field = find(root, "native-keyboard-field") ?: error("Flutter text input is absent from Android semantics")
                assertTrue(field.performAction(AccessibilityNodeInfo.ACTION_CLICK))
                Thread.sleep(500)
                automation.executeShellCommand("input text qualification").close()
                Thread.sleep(500)
                keyboard = request("state").getString("input") == "qualification"
                if (!keyboard) issues.put(JSONObject().put("check", "nativeTextInput").put("type", "ERROR"))
            } else {
                val hierarchy = AccessibilityHierarchyAndroid.newBuilder(root, context).build()
                // A Flutter host with no virtual tree would make a vacuous ATF pass.
                assertTrue("Flutter virtual semantics missing", hierarchy.activeWindow.allViews.size > 2)
                if (id == "detector-bad") {
                    assertNotNull("Bad Flutter control is absent from native semantics", find(root, "native-bad-action"))
                } else {
                    assertTrue("Native audit has no meaningful Flutter labels", labelCount(root) > 2)
                }
                for (check in AccessibilityCheckPreset.getAccessibilityHierarchyChecksForPreset(AccessibilityCheckPreset.LATEST)) {
                    for (result in check.runCheckOnHierarchy(hierarchy)) {
                        issues.put(JSONObject().put("check", check.javaClass.simpleName).put("type", result.type.toString())
                            .put("message", result.getMessage(Locale.ENGLISH).toString()).put("resultId", result.resultId)
                            .put("identifier", result.element?.resourceName ?: ""))
                    }
                }
                if (id == "detector-bad") {
                    detector = listOf("TouchTargetSizeCheck", "SpeakableTextPresentCheck").all { expectedCheck ->
                        (0 until issues.length()).any { index ->
                            val issue = issues.getJSONObject(index)
                            val identifier = issue.optString("identifier")
                            issue.optString("type") == "ERROR" && issue.optString("check") == expectedCheck &&
                                (identifier == "native-bad-action" || identifier.endsWith("/native-bad-action"))
                        }
                    }
                }
            }
            val failed = (0 until issues.length()).any { issues.getJSONObject(it).optString("type") == "ERROR" } ||
                sample.getJSONArray("frameworkErrors").length() != 0
            frameworkErrorCount += sample.getJSONArray("frameworkErrors").length()
            request("result", JSONObject().put("id", id).put("platform", "android").put("issues", issues)
                .put("passed", if (id == "detector-bad") detector else !failed).put("nodesSource", "UiAutomation.AccessibilityNodeInfo").put("semantics", semantics(root)))
            cases++
        }
        val report = request("state")
        context.openFileOutput("qualification-native-audit.json", 0).use { it.write(report.toString(2).toByteArray()) }
        assertEquals(report.getInt("expected"), cases)
        assertTrue("Bad control was not rejected by ATF", detector)
        assertTrue("Native editable semantics did not update Flutter", keyboard)
        assertEquals("Flutter framework errors", 0, frameworkErrorCount)
    }
}
