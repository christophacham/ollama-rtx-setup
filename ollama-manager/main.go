package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("205"))
	loadedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	helpStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	cursorStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
)

type model struct {
	models  []string
	loaded  map[string]bool
	cursor  int
	status  string
	quiting bool
}

func getModels() []string {
	out, err := exec.Command("ollama", "list").Output()
	if err != nil {
		return nil
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	var models []string
	for i, line := range lines {
		if i == 0 {
			continue // skip header
		}
		fields := strings.Fields(line)
		if len(fields) > 0 {
			models = append(models, fields[0])
		}
	}
	return models
}

func getLoaded() map[string]bool {
	loaded := make(map[string]bool)
	out, err := exec.Command("ollama", "ps").Output()
	if err != nil {
		return loaded
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	for i, line := range lines {
		if i == 0 {
			continue // skip header
		}
		fields := strings.Fields(line)
		if len(fields) > 0 {
			loaded[fields[0]] = true
		}
	}
	return loaded
}

func initialModel() model {
	return model{
		models: getModels(),
		loaded: getLoaded(),
		status: "Ready",
	}
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			m.quiting = true
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.models)-1 {
				m.cursor++
			}
		case "r", "enter":
			if len(m.models) > 0 {
				name := m.models[m.cursor]
				m.status = fmt.Sprintf("Loading %s...", name)
				go exec.Command("ollama", "run", name).Start()
				m.loaded[name] = true
				m.status = fmt.Sprintf("Started %s", name)
			}
		case "s":
			if len(m.models) > 0 {
				name := m.models[m.cursor]
				m.status = fmt.Sprintf("Stopping %s...", name)
				exec.Command("ollama", "stop", name).Run()
				delete(m.loaded, name)
				m.status = fmt.Sprintf("Stopped %s", name)
			}
		case "u":
			m.status = "Unloading all models..."
			for name := range m.loaded {
				exec.Command("ollama", "stop", name).Run()
			}
			m.loaded = make(map[string]bool)
			m.status = "All models unloaded"
		case "R":
			m.models = getModels()
			m.loaded = getLoaded()
			m.status = "Refreshed"
		}
	}
	return m, nil
}

func (m model) View() string {
	if m.quiting {
		return ""
	}

	var b strings.Builder

	b.WriteString(titleStyle.Render("Ollama Model Manager"))
	b.WriteString("\n\n")

	if len(m.models) == 0 {
		b.WriteString("  No models found. Run 'ollama pull <model>' first.\n")
	} else {
		for i, name := range m.models {
			cursor := "  "
			if i == m.cursor {
				cursor = cursorStyle.Render("> ")
			}

			status := ""
			if m.loaded[name] {
				status = loadedStyle.Render(" [LOADED]")
			}

			b.WriteString(fmt.Sprintf("%s%s%s\n", cursor, name, status))
		}
	}

	b.WriteString("\n")
	b.WriteString(helpStyle.Render("r/Enter: Run  s: Stop  u: Unload All  R: Refresh  q: Quit"))
	b.WriteString("\n")
	b.WriteString(fmt.Sprintf("\nStatus: %s", m.status))

	return b.String()
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}
