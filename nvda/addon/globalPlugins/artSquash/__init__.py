# Art Squash: silences decorative box-drawing and block characters in chosen applications.
# Copyright (C) 2026 Victor Tsaran
# This file is covered by the GNU General Public License, version 2 or later.
# See the file LICENSE for more details.

import re

import addonHandler
import api
import config
import globalPluginHandler
import ui
import wx
from gui import guiHelper
from gui.settingsDialogs import NVDASettingsDialog, SettingsPanel
from scriptHandler import script
from speech.commands import SuppressUnicodeNormalizationCommand
from speech.extensions import filter_speechSequence

addonHandler.initTranslation()

CONF_SECTION = "artSquash"
APPLY_SELECTED = "selected"
APPLY_ALL = "all"
# NVDA app names (executable names without ".exe") of common terminals and editors.
DEFAULT_APPS = ("windowsterminal", "openconsole", "cmd", "powershell", "pwsh", "code")

config.conf.spec[CONF_SECTION] = {
	"enabled": "boolean(default=True)",
	"applyTo": f'option("{APPLY_SELECTED}", "{APPLY_ALL}", default="{APPLY_SELECTED}")',
	"apps": "string_list(default=list({}))".format(", ".join(f'"{app}"' for app in DEFAULT_APPS)),
}

# Box Drawing (U+2500-257F) and Block Elements (U+2580-259F).
ART_PATTERN = re.compile("[─-▟]+")


def conf():
	return config.conf[CONF_SECTION]


def focusedAppName():
	appModule = getattr(api.getFocusObject(), "appModule", None)
	return appModule.appName if appModule else None


def normalizeAppName(name):
	name = name.strip().lower()
	return name[: -len(".exe")] if name.endswith(".exe") else name


def appliesToFocusedApp():
	c = conf()
	return c["applyTo"] == APPLY_ALL or focusedAppName() in c["apps"]


def filterSpeech(speechSequence):
	if not conf()["enabled"]:
		return speechSequence
	# NVDA marks character-by-character reading (spelling) with this command.
	# Leave it alone so a single character can still be inspected.
	if any(isinstance(item, SuppressUnicodeNormalizationCommand) for item in speechSequence):
		return speechSequence
	if not any(isinstance(item, str) and ART_PATTERN.search(item) for item in speechSequence):
		return speechSequence
	if not appliesToFocusedApp():
		return speechSequence
	filtered = []
	for item in speechSequence:
		if isinstance(item, str) and ART_PATTERN.search(item):
			# A space keeps text on either side of a border from running together.
			item = ART_PATTERN.sub(" ", item)
			if not item.strip():
				continue
		filtered.append(item)
	return filtered


class ArtSquashSettingsPanel(SettingsPanel):
	# Translators: Title of the Art Squash category in NVDA's settings dialog.
	title = _("Art Squash")

	def makeSettings(self, settingsSizer):
		helper = guiHelper.BoxSizerHelper(self, sizer=settingsSizer)
		c = conf()

		self.enabledCheckBox = helper.addItem(
			# Translators: Checkbox in the Art Squash settings panel.
			wx.CheckBox(self, label=_("&Silence decorative box-drawing characters")),
		)
		self.enabledCheckBox.SetValue(c["enabled"])

		self.applyToValues = (APPLY_SELECTED, APPLY_ALL)
		self.applyToChoice = helper.addLabeledControl(
			# Translators: Label of a choice in the Art Squash settings panel.
			_("A&pply to:"),
			wx.Choice,
			choices=[
				# Translators: Option for where Art Squash applies.
				_("Only the applications listed below"),
				# Translators: Option for where Art Squash applies.
				_("All applications"),
			],
		)
		self.applyToChoice.SetSelection(self.applyToValues.index(c["applyTo"]))

		self.appsList = helper.addLabeledControl(
			# Translators: Label of the application list in the Art Squash settings panel.
			_("&Applications:"),
			wx.ListBox,
			choices=list(c["apps"]),
		)
		if self.appsList.GetCount():
			self.appsList.SetSelection(0)

		self.newAppEdit = helper.addLabeledControl(
			# Translators: Label of an edit field for adding an application name, e.g. windowsterminal.
			_("&New application name (for example windowsterminal):"),
			wx.TextCtrl,
		)

		buttons = guiHelper.ButtonHelper(wx.HORIZONTAL)
		# Translators: Button that adds the typed application name to the list.
		addButton = buttons.addButton(self, label=_("A&dd"))
		# Translators: Button that removes the selected application from the list.
		removeButton = buttons.addButton(self, label=_("&Remove"))
		helper.addItem(buttons)
		addButton.Bind(wx.EVT_BUTTON, self.onAdd)
		removeButton.Bind(wx.EVT_BUTTON, self.onRemove)

	def onAdd(self, evt):
		name = normalizeAppName(self.newAppEdit.GetValue())
		if not name:
			return
		existing = self.appsList.FindString(name)
		if existing == wx.NOT_FOUND:
			existing = self.appsList.Append(name)
		self.appsList.SetSelection(existing)
		self.newAppEdit.Clear()
		self.appsList.SetFocus()

	def onRemove(self, evt):
		index = self.appsList.GetSelection()
		if index == wx.NOT_FOUND:
			return
		self.appsList.Delete(index)
		if self.appsList.GetCount():
			self.appsList.SetSelection(min(index, self.appsList.GetCount() - 1))
		self.appsList.SetFocus()

	def onSave(self):
		c = conf()
		c["enabled"] = self.enabledCheckBox.GetValue()
		c["applyTo"] = self.applyToValues[self.applyToChoice.GetSelection()]
		c["apps"] = list(self.appsList.GetStrings())


class GlobalPlugin(globalPluginHandler.GlobalPlugin):
	# Translators: Category of Art Squash commands in the Input Gestures dialog.
	scriptCategory = _("Art Squash")

	def __init__(self, *args, **kwargs):
		super().__init__(*args, **kwargs)
		filter_speechSequence.register(filterSpeech)
		NVDASettingsDialog.categoryClasses.append(ArtSquashSettingsPanel)

	def terminate(self):
		filter_speechSequence.unregister(filterSpeech)
		if ArtSquashSettingsPanel in NVDASettingsDialog.categoryClasses:
			NVDASettingsDialog.categoryClasses.remove(ArtSquashSettingsPanel)
		super().terminate()

	@script(
		# Translators: Description of a command in the Input Gestures dialog.
		description=_("Turns silencing of decorative box-drawing characters on or off"),
	)
	def script_toggle(self, gesture):
		c = conf()
		c["enabled"] = not c["enabled"]
		# Translators: Reported when Art Squash is turned on or off.
		ui.message(_("ASCII art silenced") if c["enabled"] else _("ASCII art spoken"))

	@script(
		# Translators: Description of a command in the Input Gestures dialog.
		description=_("Adds the current application to the Art Squash list, or removes it"),
	)
	def script_toggleCurrentApp(self, gesture):
		appName = focusedAppName()
		if not appName:
			return
		c = conf()
		apps = list(c["apps"])
		if appName in apps:
			apps.remove(appName)
			# Translators: Reported when an application is removed from the Art Squash list.
			message = _("{app} removed from Art Squash").format(app=appName)
		else:
			apps.append(appName)
			# Translators: Reported when an application is added to the Art Squash list.
			message = _("{app} added to Art Squash").format(app=appName)
		c["apps"] = apps
		if c["applyTo"] == APPLY_ALL:
			# Translators: Added to the message above when Art Squash applies to all applications.
			message += ". " + _("Art Squash currently applies to all applications")
		ui.message(message)
