package mcpconnect

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// This file implements just enough of MCP's Streamable HTTP transport
// (2025-03-26 spec) for a small, fixed tool set: initialize, tools/list, and
// tools/call over a single stateless POST /mcp endpoint. Every tool call
// carries its own bearer token (see mcp_auth.go), so the server needs no
// session state between requests — deliberately skipping the spec's optional
// Mcp-Session-Id / SSE-stream machinery, which exists for servers that do
// need cross-request state or server-initiated pushes. Hand-rolled rather
// than pulled from an SDK: no MCP Go SDK was reachable/verifiable in this
// environment (see the accompanying PR description), and the wire surface
// this server actually needs — three JSON-RPC methods, no streaming — is
// small enough that hand-rolling it is less risk than an unverified new
// dependency.

const jsonRPCVersion = "2.0"

type rpcRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

const (
	rpcParseError     = -32700
	rpcInvalidRequest = -32600
	rpcMethodNotFound = -32601
	rpcInvalidParams  = -32602
	rpcInternalError  = -32603
)

// HandleMCP handles POST /mcp — every tool call an approved external client
// makes. Wrapped by requireMCPAuth, so mcpIdentityFrom(r.Context()) is always
// populated by the time this runs.
func (rt *Router) HandleMCP(w http.ResponseWriter, r *http.Request) {
	var req rpcRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeRPCError(w, nil, rpcParseError, "Parse error")
		return
	}

	// A notification (no id) gets no response body at all, per JSON-RPC 2.0 —
	// "notifications/initialized" is the only one this server expects.
	isNotification := len(req.ID) == 0

	id, ok := mcpIdentityFrom(r.Context())
	if !ok {
		writeRPCError(w, req.ID, rpcInternalError, "Missing connection identity")
		return
	}

	switch req.Method {
	case "initialize":
		rt.rpcInitialize(w, req)
	case "notifications/initialized":
		w.WriteHeader(http.StatusAccepted)
	case "tools/list":
		rt.rpcToolsList(w, req)
	case "tools/call":
		rt.rpcToolsCall(w, r, req, id)
	default:
		if isNotification {
			w.WriteHeader(http.StatusAccepted)
			return
		}
		writeRPCError(w, req.ID, rpcMethodNotFound, "Method not found: "+req.Method)
	}
}

func (rt *Router) rpcInitialize(w http.ResponseWriter, req rpcRequest) {
	writeRPCResult(w, req.ID, map[string]any{
		"protocolVersion": "2025-03-26",
		"capabilities":    map[string]any{"tools": map[string]any{}},
		"serverInfo":      map[string]any{"name": "mindforge", "version": "1.0.0"},
	})
}

func (rt *Router) rpcToolsList(w http.ResponseWriter, req rpcRequest) {
	defs := make([]map[string]any, 0, len(tools))
	for _, t := range tools {
		defs = append(defs, map[string]any{
			"name":        t.Name,
			"description": t.Description,
			"inputSchema": t.InputSchema,
		})
	}
	writeRPCResult(w, req.ID, map[string]any{"tools": defs})
}

func (rt *Router) rpcToolsCall(w http.ResponseWriter, r *http.Request, req rpcRequest, id mcpIdentity) {
	var params struct {
		Name      string         `json:"name"`
		Arguments map[string]any `json:"arguments"`
	}
	if err := json.Unmarshal(req.Params, &params); err != nil {
		writeRPCError(w, req.ID, rpcInvalidParams, "Invalid params")
		return
	}

	resultJSON, err := rt.callTool(r.Context(), id, params.Name, params.Arguments)
	if err != nil {
		slog.Warn("mcpconnect: tool call failed", "tool", params.Name, "user_id", id.UserID, "error", err)
		// Tool errors (bad args, missing scope, not enrolled) surface as a
		// successful JSON-RPC response with isError=true, per the MCP spec —
		// distinct from a transport-level JSON-RPC error, which would mean the
		// request itself was malformed rather than the tool failing.
		writeRPCResult(w, req.ID, map[string]any{
			"content": []map[string]any{{"type": "text", "text": err.Error()}},
			"isError": true,
		})
		return
	}

	writeRPCResult(w, req.ID, map[string]any{
		"content": []map[string]any{{"type": "text", "text": string(resultJSON)}},
	})
}

func writeRPCResult(w http.ResponseWriter, id json.RawMessage, result any) {
	payload, err := json.Marshal(result)
	if err != nil {
		writeRPCError(w, id, rpcInternalError, "Internal error")
		return
	}
	writeSpecJSON(w, http.StatusOK, rpcResponse{JSONRPC: jsonRPCVersion, ID: id, Result: payload})
}

func writeRPCError(w http.ResponseWriter, id json.RawMessage, code int, message string) {
	writeSpecJSON(w, http.StatusOK, rpcResponse{JSONRPC: jsonRPCVersion, ID: id, Error: &rpcError{Code: code, Message: message}})
}
