package main

import (
	"archive/zip"
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func main() {
	if len(os.Args) != 4 {
		fmt.Println("Usage: gen_doxygen_docs <project.zip> <docs.zip> <output_dir>")
		return
	}

	projectZip := os.Args[1]
	docsZip := os.Args[2]
	outputDir := os.Args[3]

	projectDir := filepath.Join(outputDir, "project")
	docsDir := filepath.Join(outputDir, "docs")
	doxDir := filepath.Join(outputDir, "doxygen_md")

	mkdirAll(projectDir)
	mkdirAll(docsDir)
	mkdirAll(doxDir)

	check(unzip(projectZip, projectDir))
	check(unzip(docsZip, docsDir))

	reFile := regexp.MustCompile(`\\file\s+([^\s]+)`)

	var doxFiles []string

	err := filepath.Walk(docsDir, func(mdPath string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || filepath.Ext(mdPath) != ".md" {
			return nil
		}

		file, err := os.Open(mdPath)
		if err != nil {
			return err
		}
		defer file.Close()

		scanner := bufio.NewScanner(file)
		var filePath string
		lines := []string{}
		for i := 0; scanner.Scan() && i < 10; i++ {
			line := scanner.Text()
			lines = append(lines, line)
			if filePath == "" {
				if match := reFile.FindStringSubmatch(line); match != nil {
					filePath = match[1]
				}
			}
		}
		if filePath == "" {
			fmt.Printf("No \\file found in %s\n", mdPath)
			return nil
		}

		content, err := os.ReadFile(mdPath)
		if err != nil {
			return err
		}

		doxName := filepath.Base(mdPath)
		doxName = strings.TrimSuffix(doxName, ".md") + ".dox"
		doxPath := filepath.Join(doxDir, doxName)

		out, err := os.Create(doxPath)
		if err != nil {
			return err
		}
		defer out.Close()

		// Начало блока комментария
		_, _ = fmt.Fprintf(out, "/** \\file %s\n", filePath)
		_, _ = fmt.Fprintln(out, " *  \\brief Документация\n *")

		scanner = bufio.NewScanner(strings.NewReader(string(content)))
		for scanner.Scan() {
			line := scanner.Text()
			// Экранирование случайного закрытия комментария
			line = strings.ReplaceAll(line, "*/", "*\\/")
			_, _ = fmt.Fprintf(out, " * %s\n", line)
		}

		_, _ = fmt.Fprintln(out, " */")

		doxFiles = append(doxFiles, doxPath)
		fmt.Printf("Generated: %s → %s\n", mdPath, filePath)
		return nil
	})
	check(err)

	check(writeDoxyfile(filepath.Join(outputDir, "Doxyfile"), projectDir, doxDir))
	fmt.Printf("\n✅ Doxyfile успешно создан. Запустите: doxygen %s\n", filepath.Join(outputDir, "Doxyfile"))
}

func unzip(src, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		outPath := filepath.Join(dest, f.Name)

		if f.FileInfo().IsDir() {
			mkdirAll(outPath)
			continue
		}

		if err := mkdirAll(filepath.Dir(outPath)); err != nil {
			return err
		}

		rc, err := f.Open()
		if err != nil {
			return err
		}
		defer rc.Close()

		outFile, err := os.Create(outPath)
		if err != nil {
			return err
		}
		defer outFile.Close()

		_, err = io.Copy(outFile, rc)
		if err != nil {
			return err
		}
	}
	return nil
}

func writeDoxyfile(path, codeDir, doxDir string) error {
	content := fmt.Sprintf(`# Auto-generated Doxygen config
PROJECT_NAME           = "GeneratedProjectDocs"
OUTPUT_DIRECTORY       = docs_output
INPUT                  = %s \\
                         %s
FILE_PATTERNS          = *.cs *.dox
RECURSIVE              = YES
EXTENSION_MAPPING      = md=markdown
MARKDOWN_SUPPORT       = YES
GENERATE_LATEX         = NO
GENERATE_HTML          = YES
GENERATE_TREEVIEW      = YES
HTML_OUTPUT            = html
`, codeDir, doxDir)

	return os.WriteFile(path, []byte(content), 0644)
}

func mkdirAll(path string) error {
	return os.MkdirAll(path, 0755)
}

func check(err error) {
	if err != nil {
		panic(err)
	}
}
