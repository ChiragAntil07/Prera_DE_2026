# Problem Understanding — Zomato Food Delivery Data Engineering

## 1. Project Overview
This project focuses on designing and implementing a relational database for a food delivery platform similar to Zomato. The database stores and manages information related to cities, localities, customers, restaurants, menu items, delivery partners, coupons, orders, order items, payments, and reviews.

The objective is to create a structured, reliable, and consistent database using PostgreSQL.

## 2. Problem Statement
Food delivery platforms generate large amounts of data through customer registrations, restaurant listings, menu management, order placement, payment processing, delivery operations, and customer reviews.

A properly designed database is required to:
- Store platform data in a structured manner.
- Maintain relationships between entities.
- Reduce data redundancy.
- Ensure data integrity through constraints.
- Support efficient querying and analysis.

## 3. Objectives
- Analyze the provided CSV datasets.
- Identify entities, attributes, and relationships.
- Design a normalized relational database schema.
- Implement tables using PostgreSQL.
- Load the provided seed data using `COPY`.
- Validate row counts and integrity constraints.

## 4. Technology Stack
- **Database:** PostgreSQL
- **Language:** SQL
- **Data Source:** CSV seed datasets
- **Tools:** PostgreSQL CLI / pgAdmin

## 5. Dataset Overview
The project contains 11 datasets:

| Dataset | Expected Records |
|---|---:|
| cities | 10 |
| localities | 100 |
| customers | 25,000 |
| restaurants | 2,500 |
| menu_items | 50,000 |
| delivery_partners | 2,000 |
| coupons | 30 |
| orders | 150,000 |
| order_items | 375,000 |
| payments | 137,378 |
| reviews | 39,186 |

## 6. Expected Outcome
A PostgreSQL database named `zomato_db` with a dedicated `zomato` schema, containing all 11 tables, successfully loaded datasets, and documented schema design and integrity validation results.