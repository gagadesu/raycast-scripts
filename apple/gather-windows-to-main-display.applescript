#!/usr/bin/osascript

# @raycast.title Gather Windows to Main Display
# @raycast.author gagadesu
# @raycast.authorURL https://github.com/gagadesu
# @raycast.description Bring visible windows from other displays onto the main display.
# @raycast.icon 🪟
# @raycast.mode silent
# @raycast.packageName Window Management
# @raycast.schemaVersion 1

use framework "AppKit"
use scripting additions

property edgePadding : 24

on run
	set mainFrame to my mainDisplayVisibleFrame()
	if mainFrame is missing value then error "Unable to determine the main display."

	set {mainLeft, mainTop, mainWidth, mainHeight} to mainFrame
	set mainRight to mainLeft + mainWidth
	set mainBottom to mainTop + mainHeight
	set maximumWindowWidth to mainWidth - (edgePadding * 2)
	set maximumWindowHeight to mainHeight - (edgePadding * 2)
	set movedCount to 0

	tell application "System Events"
		set appList to every application process whose background only is false and visible is true

		repeat with appProc in appList
			set processName to "unknown application"
			try
				set processName to name of appProc
				if processName is not "Raycast" and processName is not "Raycast Beta" then
					tell appProc
						repeat with appWindow in windows
							try
								set isMinimized to false
								try
									set isMinimized to value of attribute "AXMinimized" of appWindow
								end try

								set isFullScreen to false
								try
									set isFullScreen to value of attribute "AXFullScreen" of appWindow
								end try

								set windowSubrole to ""
								try
									set windowSubrole to value of attribute "AXSubrole" of appWindow
								end try

								if isMinimized is false and isFullScreen is false and windowSubrole is "AXStandardWindow" then
									set {windowX, windowY} to position of appWindow
									set {windowWidth, windowHeight} to size of appWindow
									set windowCenterX to windowX + (windowWidth / 2)
									set windowCenterY to windowY + (windowHeight / 2)

									if windowCenterX < mainLeft or windowCenterX ≥ mainRight or windowCenterY < mainTop or windowCenterY ≥ mainBottom then
										set targetWidth to my minimumOf(windowWidth, maximumWindowWidth)
										set targetHeight to my minimumOf(windowHeight, maximumWindowHeight)

										if targetWidth is not windowWidth or targetHeight is not windowHeight then
											set size of appWindow to {targetWidth, targetHeight}
										end if

										set targetX to my clamped(windowX, mainLeft + edgePadding, mainRight - targetWidth - edgePadding)
										set targetY to my clamped(windowY, mainTop + edgePadding, mainBottom - targetHeight - edgePadding)
										set position of appWindow to {targetX, targetY}
										set movedCount to movedCount + 1
									end if
								end if
							on error errorMessage number errorNumber
								log "Skipped a window in " & processName & ": " & errorMessage & " (" & errorNumber & ")"
							end try
						end repeat
					end tell
				end if
			on error errorMessage number errorNumber
				log "Skipped " & processName & ": " & errorMessage & " (" & errorNumber & ")"
			end try
		end repeat
	end tell

	return movedCount
end run

on mainDisplayVisibleFrame()
	current application's NSApplication's sharedApplication()
	set screenList to current application's NSScreen's screens()
	if (screenList's |count|() as integer) is 0 then return missing value

	-- NSScreen lists the display containing the menu bar first. Its frame origin
	-- is the origin of macOS's global display coordinate system.
	set mainScreen to screenList's firstObject()
	set fullFrame to mainScreen's frame()
	set visibleFrame to mainScreen's visibleFrame()

	set fullTop to current application's NSMaxY(fullFrame)
	set visibleLeft to current application's NSMinX(visibleFrame)
	set visibleTop to fullTop - (current application's NSMaxY(visibleFrame))
	set visibleWidth to current application's NSWidth(visibleFrame)
	set visibleHeight to current application's NSHeight(visibleFrame)

	set visibleLeft to visibleLeft as integer
	set visibleTop to visibleTop as integer
	set visibleWidth to visibleWidth as integer
	set visibleHeight to visibleHeight as integer
	return {visibleLeft, visibleTop, visibleWidth, visibleHeight}
end mainDisplayVisibleFrame

on clamped(theValue, lowerBound, upperBound)
	if upperBound < lowerBound then return lowerBound
	if theValue < lowerBound then return lowerBound
	if theValue > upperBound then return upperBound
	return theValue
end clamped

on minimumOf(firstValue, secondValue)
	if firstValue < secondValue then return firstValue
	return secondValue
end minimumOf
