# Sync Service 

## Problem Statement

```bash
Problem Statement: 
Design a bi-directional record synchronization service that can handle CRUD (Create, Read, Update, Delete) operations between two systems:
• System A (Internal): We have full access, including back-end services and storage.
• System B (External): Accessible only via API. External APIs may have rate limits, and the data models may differ from our internal system. 

The system must handle over 300 million synchronization requests daily, with near real-time latency and 99.9% availability.

Additional Requirements:
• External APIs cannot support unlimited requests.
• Some data transformations are required to map between internal and external schemas.
• The system must support multiple CRM providers.
• Synchronization must occur record-by-record.
• Input/output should be validated against predefined schemas.
• Data must be transformed into/from the specific object models before being processed.
• Sync actions (CRUD) are determined by pre-configured rules or triggers.

Task:
Your task is to design and implement one key part of the synchronization system.
What:
• Define and frame the problem clearly, including your assumptions.
• Explore alternative solutions, trade-offs, and the rationale for your design choices.
• A concrete implementation of one part of the system (not the whole system). Feel free to mock external systems or services as needed.
• You can use any programming language or framework youre comfortable with.

Guidelines:
• You are not supposed to take any AI assistant for this exercise
• Start by defining a specific sub-problem youd like to solve (e.g., syncing updates from internal to external, handling conflict resolution, schema transformation logic, etc.).
• Include a high-level design overview and the assumptions youre making.
• Implement your chosen part with clean, well-structured code, and include comments or a
README to explain how to run and test it.
• You are encouraged to be creative in how you approach the solution. Were evaluating your
thinking process, not just the final code.

Submission:
Please provide:
• A brief document outlining your approach and design decisions.
• The code for your implementation.
• Any notes or instructions needed to run your solution.
```