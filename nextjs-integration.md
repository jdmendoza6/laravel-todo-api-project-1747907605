# Integrating with Next.js Frontend

To connect your Next.js application to this Laravel API, you'll need to modify the server actions to use the API instead of in-memory storage.

## Modify Next.js Server Actions

Replace the content of `nextjs-server-actions/app/actions.ts` with:

```typescript
'use server';

import { revalidatePath } from 'next/cache';
import { cache } from 'react';

// Define the Todo type
export type Todo = {
  id: string;
  text: string;
  completed: boolean;
};

const API_URL = 'http://localhost:8000/api';

// Get all todos with caching for better performance
export const getTodos = cache(async (): Promise<Todo[]> => {
  const response = await fetch(`${API_URL}/todos`, {
    cache: 'no-store',
  });
  
  if (!response.ok) {
    throw new Error('Failed to fetch todos');
  }
  
  return response.json();
});

// Add a new todo
export async function addTodo(formData: FormData) {
  const text = formData.get('text') as string;
  
  if (!text || text.trim() === '') {
    return { error: 'Todo text cannot be empty' };
  }

  const response = await fetch(`${API_URL}/todos`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ text: text.trim() }),
  });
  
  if (!response.ok) {
    return { error: 'Failed to add todo' };
  }
  
  revalidatePath('/');
  return { success: true };
}

// Toggle todo completion status
export async function toggleTodo(id: string) {
  const response = await fetch(`${API_URL}/todos/${id}/toggle`, {
    method: 'PUT',
  });
  
  if (!response.ok) {
    return { error: 'Failed to toggle todo' };
  }
  
  revalidatePath('/');
  return { success: true };
}

// Delete a todo
export async function deleteTodo(id: string) {
  const response = await fetch(`${API_URL}/todos/${id}`, {
    method: 'DELETE',
  });
  
  if (!response.ok) {
    return { error: 'Failed to delete todo' };
  }
  
  revalidatePath('/');
  return { success: true };
}
```

This will connect your Next.js application to the Laravel API while maintaining the same interface for your components.