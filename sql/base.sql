set schema = public;

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: clients; Type: TABLE; Schema: public; Owner: invoice; Tablespace: 
--

CREATE TABLE clients (
    id character varying(20) NOT NULL,
    ragsoc character varying(255),
    address character varying(255),
    zip character varying(10),
    city character varying(127),
    prov character varying(4),
    country character varying(2)
);


ALTER TABLE clients OWNER TO invoice;

--
-- Name: COLUMN clients.id; Type: COMMENT; Schema: public; Owner: invoice
--

COMMENT ON COLUMN clients.id IS 'Partita iva o codice fiscale';


--
-- Name: COLUMN clients.ragsoc; Type: COMMENT; Schema: public; Owner: invoice
--

COMMENT ON COLUMN clients.ragsoc IS 'Ragione sociale';


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: invoice; Tablespace: 
--

CREATE TABLE invoices (
    id bigint NOT NULL,
    emitted date,
    expires date,
    products json,
    total integer,
    accounted boolean,
    client character varying(20)
);


ALTER TABLE invoices OWNER TO invoice;

--
-- Name: COLUMN invoices.id; Type: COMMENT; Schema: public; Owner: invoice
--

COMMENT ON COLUMN invoices.id IS 'date +%s , tronca gli ultimi due';


--
-- Name: COLUMN invoices.client; Type: COMMENT; Schema: public; Owner: invoice
--

COMMENT ON COLUMN invoices.client IS 'p.iva, cod.fisc';


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: invoice
--


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: invoice
--

--
-- Name: pk_id; Type: CONSTRAINT; Schema: public; Owner: invoice; Tablespace: 
--

ALTER TABLE ONLY clients
    ADD CONSTRAINT pk_id PRIMARY KEY (id);


--
-- Name: pk_invoice; Type: CONSTRAINT; Schema: public; Owner: invoice; Tablespace: 
--

ALTER TABLE ONLY invoices
    ADD CONSTRAINT pk_invoice PRIMARY KEY (id);


--
-- Name: fk_piva; Type: FK CONSTRAINT; Schema: public; Owner: invoice
--

ALTER TABLE ONLY invoices
    ADD CONSTRAINT fk_piva FOREIGN KEY (client) REFERENCES clients(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: pgsql
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM pgsql;
GRANT ALL ON SCHEMA public TO pgsql;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

