package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const anthropicAPIURL = "https://api.anthropic.com/v1/messages"
const anthropicVersion = "2023-06-01"

type AnthropicProvider struct {
	apiKey string
	model  string
	client *http.Client
}

func newAnthropicProvider(apiKey, model string) *AnthropicProvider {
	if model == "" {
		model = "claude-sonnet-4-6"
	}
	return &AnthropicProvider{
		apiKey: apiKey,
		model:  model,
		client: &http.Client{},
	}
}

func (p *AnthropicProvider) Available() bool {
	return p.apiKey != ""
}

type anthropicMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type anthropicRequest struct {
	Model     string             `json:"model"`
	MaxTokens int                `json:"max_tokens"`
	System    string             `json:"system,omitempty"`
	Messages  []anthropicMessage `json:"messages"`
}

type anthropicResponse struct {
	Content []struct {
		Text string `json:"text"`
		Type string `json:"type"`
	} `json:"content"`
	Model string `json:"model"`
	Usage struct {
		InputTokens  int `json:"input_tokens"`
		OutputTokens int `json:"output_tokens"`
	} `json:"usage"`
	Error *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
}

func (p *AnthropicProvider) Complete(ctx context.Context, req CompletionRequest) (CompletionResponse, error) {
	maxTokens := req.MaxTokens
	if maxTokens <= 0 {
		maxTokens = 2048
	}

	system := req.SystemPrompt
	if req.JSONMode {
		system += "\n\nYou must respond with valid JSON only. Do not include markdown code blocks or any text outside the JSON."
	}

	body := anthropicRequest{
		Model:     p.model,
		MaxTokens: maxTokens,
		System:    system,
		Messages: []anthropicMessage{
			{Role: "user", Content: req.UserPrompt},
		},
	}

	raw, err := json.Marshal(body)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: anthropic marshal request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicAPIURL, bytes.NewReader(raw))
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: anthropic build request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("x-api-key", p.apiKey)
	httpReq.Header.Set("anthropic-version", anthropicVersion)

	resp, err := p.client.Do(httpReq)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: anthropic request: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: anthropic read response: %w", err)
	}

	var ar anthropicResponse
	if err := json.Unmarshal(respBytes, &ar); err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: anthropic parse response: %w", err)
	}

	if ar.Error != nil {
		return CompletionResponse{}, fmt.Errorf("ai: anthropic api error [%s]: %s", ar.Error.Type, ar.Error.Message)
	}

	if len(ar.Content) == 0 {
		return CompletionResponse{}, fmt.Errorf("ai: anthropic empty response")
	}

	return CompletionResponse{
		Content: ar.Content[0].Text,
		Model:   ar.Model,
		Usage: UsageStats{
			InputTokens:  ar.Usage.InputTokens,
			OutputTokens: ar.Usage.OutputTokens,
		},
	}, nil
}
